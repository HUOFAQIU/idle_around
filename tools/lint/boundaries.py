"""依赖边界规则：层表与 autoload 映射见 boundaries.toml。"""

import re
import tomllib
from dataclasses import dataclass
from pathlib import Path

from diagnostics import Diagnostic
from lexer import code_lines
from rules import Rule

CONFIG_PATH = Path(__file__).resolve().parent / "boundaries.toml"
PROJECT_FILE = "project.godot"

IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
CLASS_DECLARATION = re.compile(
    r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE
)
RES_LITERAL = re.compile(r"res://([A-Za-z0-9_./%-]+)")


@dataclass(frozen=True)
class Layer:
    name: str
    paths: tuple[str, ...]
    reads: tuple[str, ...]


def _matches(prefix: str, relative: str) -> bool:
    if prefix.endswith("/"):
        return relative.startswith(prefix)
    return relative == prefix


def _mask_strings(line: str) -> str:
    masked: list[str] = []
    quote = ""
    index = 0
    while index < len(line):
        char = line[index]
        if quote:
            if char == "\\":
                masked.append("  ")
                index += 2
                continue
            if char == quote:
                quote = ""
                masked.append(char)
            else:
                masked.append(" ")
            index += 1
            continue
        if char in ("'", '"'):
            quote = char
        masked.append(char)
        index += 1
    return "".join(masked)


class DependencyBoundaryRule(Rule):
    id = "dependency-boundary"
    description = "跨层引用只走层表允许的方向"
    severity = "error"
    extensions = frozenset({".gd", ".tscn", ".tres"})

    def __init__(self, root: Path, config_path: Path | None = None) -> None:
        self.root = Path(root).resolve()
        self.config_path = (
            Path(config_path) if config_path is not None else CONFIG_PATH
        )
        self.layers: list[Layer] = []
        self.autoloads: dict[str, str] = {}
        self.class_map: dict[str, str] = {}
        self._pending: list[Diagnostic] = []
        self._load()
        self._index_classes()

    def check(
        self, path: Path, source: str, root: Path
    ) -> list[Diagnostic]:
        findings, self._pending = self._pending, []
        relative = self._relative(path)
        if relative is None:
            return findings

        source_layer = self._layer_of(relative)
        if source_layer is None:
            findings.append(
                Diagnostic(
                    path,
                    1,
                    1,
                    self.id,
                    f"文件不属于任何层：{relative}；"
                    "在 tools/lint/boundaries.toml 补前缀",
                    self.severity,
                )
            )
            return findings

        for target, (line_number, count) in sorted(
            self._edges(path, source).items()
        ):
            target_layer = self._layer_of(target)
            if target_layer is None or target_layer == source_layer:
                continue
            if self._allowed(source_layer, target):
                continue
            findings.append(
                Diagnostic(
                    path,
                    line_number,
                    1,
                    self.id,
                    f"{source_layer} 层不能读 {target_layer} 层："
                    f"{target}（{count} 处引用）",
                    self.severity,
                )
            )
        return findings

    def _load(self) -> None:
        if not self.config_path.is_file():
            self._pending.append(
                self._config_error(f"缺少层表：{self.config_path}")
            )
            return
        try:
            data = tomllib.loads(self.config_path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, tomllib.TOMLDecodeError) as error:
            self._pending.append(self._config_error(f"层表读不出：{error}"))
            return

        for item in data.get("layer", []):
            name = str(item.get("name", "")).strip()
            paths = tuple(str(prefix) for prefix in item.get("paths", []))
            if not name or not paths:
                self._pending.append(
                    self._config_error(f"层缺 name 或 paths：{item}")
                )
                continue
            reads = tuple(str(prefix) for prefix in item.get("reads", []))
            self.layers.append(Layer(name, paths, reads))

        self.autoloads = {
            str(name): str(target).removeprefix("res://")
            for name, target in data.get("autoload", {}).items()
        }
        self._check_autoload_drift()

    def _check_autoload_drift(self) -> None:
        declared = self._project_autoloads()
        if declared is None:
            self._pending.append(
                self._config_error(
                    "读不到 project.godot 的 [autoload] 段，"
                    "无法校验 autoload 表"
                )
            )
            return
        missing = sorted(declared - set(self.autoloads))
        extra = sorted(set(self.autoloads) - declared)
        if missing:
            self._pending.append(
                self._config_error(
                    "autoload 没写进层表：" + "、".join(missing)
                )
            )
        if extra:
            self._pending.append(
                self._config_error(
                    "层表里的 autoload 在 project.godot 里不存在："
                    + "、".join(extra)
                )
            )

    def _project_autoloads(self) -> set[str] | None:
        path = self.root / PROJECT_FILE
        if not path.is_file():
            return None
        declared: set[str] = set()
        in_section = False
        for line in path.read_text(encoding="utf-8").splitlines():
            stripped = line.strip()
            if stripped.startswith("[") and stripped.endswith("]"):
                in_section = stripped == "[autoload]"
                continue
            if in_section and "=" in stripped and not stripped.startswith(";"):
                declared.add(stripped.split("=", 1)[0].strip())
        return declared

    def _index_classes(self) -> None:
        for path in self.root.rglob("*.gd"):
            relative = path.relative_to(self.root)
            if any(part.startswith(".") for part in relative.parts):
                continue
            try:
                source = path.read_text(encoding="utf-8")
            except (OSError, UnicodeDecodeError):
                continue
            match = CLASS_DECLARATION.search(source)
            if match is not None:
                self.class_map.setdefault(match.group(1), relative.as_posix())

    def _edges(
        self, path: Path, source: str
    ) -> dict[str, tuple[int, int]]:
        edges: dict[str, list[int]] = {}

        def add(target: str, line_number: int) -> None:
            entry = edges.get(target)
            if entry is None:
                edges[target] = [line_number, 1]
            else:
                entry[1] += 1

        is_gd = path.suffix.lower() == ".gd"
        for line_number, line in code_lines(source):
            for match in RES_LITERAL.finditer(line):
                add(match.group(1), line_number)
            if not is_gd:
                continue
            for match in IDENTIFIER.finditer(_mask_strings(line)):
                name = match.group(0)
                target = self.class_map.get(name) or self.autoloads.get(name)
                if target is not None:
                    add(target, line_number)
        return {
            target: (entry[0], entry[1]) for target, entry in edges.items()
        }

    def _allowed(self, source_layer: str, target: str) -> bool:
        for layer in self.layers:
            if layer.name != source_layer:
                continue
            if "*" in layer.reads:
                return True
            return any(_matches(prefix, target) for prefix in layer.reads)
        return False

    def _layer_of(self, relative: str) -> str | None:
        best: str | None = None
        best_length = -1
        for layer in self.layers:
            for prefix in layer.paths:
                if len(prefix) > best_length and _matches(prefix, relative):
                    best = layer.name
                    best_length = len(prefix)
        return best

    def _relative(self, path: Path) -> str | None:
        try:
            return path.resolve().relative_to(self.root).as_posix()
        except ValueError:
            return None

    def _config_error(self, message: str) -> Diagnostic:
        return Diagnostic(
            self.config_path, 1, 1, self.id, message, self.severity
        )
