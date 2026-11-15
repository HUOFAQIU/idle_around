"""项目 lint 规则。"""

import re
from pathlib import Path

from diagnostics import Diagnostic
from lexer import code_lines, iter_comments

CJK = re.compile(r"[㐀-䶿一-鿿豈-﫿]")
RESOURCE_NAME = re.compile(r"resource_name\s*=\s*([\"'])(.*?)\1")
FILE_ACCESS = re.compile(r"\b(FileAccess|DirAccess)\b")
COMMENT_MARKER = re.compile(
    r"\b(?:TODO|FIXME|HACK|XXX)\b|暂时|先这样|以后再|以后优化|够用|应该没问题",
    re.IGNORECASE,
)
COMMENTED_CODE = re.compile(
    r"^#\s*(var|const|func|signal|class|if|elif|else|for|while|match|return|"
    r"await|print|pass|break|continue|extends|preload|load)\b"
)
REGION = re.compile(r"^#\s*(region|endregion)\b")

FILE_ACCESS_ALLOWED = (
    "Scripts/save/",
    "Scripts/mod/",
    "Scripts/debug/",
    "modkit/",
)


class Rule:
    id = ""
    description = ""
    severity = "error"
    extensions: frozenset[str] = frozenset()

    def applies_to(self, path: Path) -> bool:
        return path.suffix.lower() in self.extensions

    def check(
        self, path: Path, source: str, root: Path
    ) -> list[Diagnostic]:
        raise NotImplementedError


class CommentMarkerRule(Rule):
    id = "comment-marker"
    description = "注释只写事实，不为捷径辩护"
    severity = "error"
    extensions = frozenset({".gd"})

    def check(
        self, path: Path, source: str, root: Path
    ) -> list[Diagnostic]:
        findings: list[Diagnostic] = []
        for comment in iter_comments(source):
            text = comment.text
            if text.startswith("##") or REGION.match(text):
                continue
            if COMMENT_MARKER.search(text):
                findings.append(
                    Diagnostic(
                        path,
                        comment.line,
                        comment.column,
                        self.id,
                        "不要在注释里为捷径找理由；事实注释要可核对，例外走 allowlist",
                        self.severity,
                    )
                )
        return findings


class CommentedCodeRule(Rule):
    id = "commented-code"
    description = "注释掉的代码应删除"
    severity = "warning"
    extensions = frozenset({".gd"})

    def check(
        self, path: Path, source: str, root: Path
    ) -> list[Diagnostic]:
        findings: list[Diagnostic] = []
        for comment in iter_comments(source):
            text = comment.text
            if text.startswith("##") or REGION.match(text):
                continue
            if COMMENTED_CODE.match(text):
                findings.append(
                    Diagnostic(
                        path,
                        comment.line,
                        comment.column,
                        self.id,
                        "注释掉的代码应删除；版本库会保留历史",
                        self.severity,
                    )
                )
        return findings


class ResourceNameRule(Rule):
    id = "resource-name-cjk"
    description = "资源不填中文 resource_name"
    severity = "error"
    extensions = frozenset({".gd", ".tscn", ".tres"})

    def check(
        self, path: Path, source: str, root: Path
    ) -> list[Diagnostic]:
        lines = (
            code_lines(source)
            if path.suffix.lower() == ".gd"
            else list(enumerate(source.splitlines(), 1))
        )
        findings: list[Diagnostic] = []
        for line_number, line in lines:
            for match in RESOURCE_NAME.finditer(line):
                if CJK.search(match.group(2)):
                    findings.append(
                        Diagnostic(
                            path,
                            line_number,
                            match.start() + 1,
                            self.id,
                            "资源不填中文 resource_name；文件名也不带固定数值",
                            self.severity,
                        )
                    )
        return findings


class FileAccessBoundaryRule(Rule):
    id = "file-access-boundary"
    description = "文件读写集中在存档/mod/调试/打包层"
    severity = "error"
    extensions = frozenset({".gd"})

    def __init__(self, root: Path) -> None:
        self.root = root

    def check(
        self, path: Path, source: str, root: Path
    ) -> list[Diagnostic]:
        relative = path.resolve().relative_to(root.resolve()).as_posix()
        if relative.startswith(FILE_ACCESS_ALLOWED):
            return []

        findings: list[Diagnostic] = []
        for line_number, line in code_lines(source):
            if FILE_ACCESS.search(line):
                findings.append(
                    Diagnostic(
                        path,
                        line_number,
                        1,
                        self.id,
                        "文件读写集中在存档/mod/调试/打包层；其他层走现有接口",
                        self.severity,
                    )
                )
        return findings


class ModPathRule(Rule):
    id = "mod-path-root"
    description = "mod 根路径只从 ModPaths 取"
    severity = "error"
    extensions = frozenset({".gd"})

    ALLOWED_FILE = "Scripts/mod/mod_paths.gd"
    ROOT_LITERAL = re.compile(
        r"""["'](?:res://base_mods|user://mods|res://mods|user://mods\.cfg)["']"""
    )
    ROOT_FORMAT = re.compile(
        r"""["'](?:res://base_mods|user://mods|res://mods)/%(?:s|d)[^"']*["']"""
    )
    ROOT_DIR = re.compile(
        r"""["'](?:res://base_mods|user://mods|res://mods)/["']"""
    )

    def check(
        self, path: Path, source: str, root: Path
    ) -> list[Diagnostic]:
        relative = path.resolve().relative_to(root.resolve()).as_posix()
        if relative == self.ALLOWED_FILE or relative.startswith("modkit/"):
            return []

        findings: list[Diagnostic] = []
        for line_number, line in code_lines(source):
            if (
                self.ROOT_LITERAL.search(line)
                or self.ROOT_FORMAT.search(line)
                or self.ROOT_DIR.search(line)
            ):
                findings.append(
                    Diagnostic(
                        path,
                        line_number,
                        1,
                        self.id,
                        "mod 根路径只从 ModPaths 取；不要裸写 res://base_mods / user://mods",
                        self.severity,
                    )
                )
        return findings


class InlineColorRule(Rule):
    id = "inline-color"
    description = "颜色抽成命名常量或走 GameColors"
    severity = "error"
    extensions = frozenset({".gd"})

    COLOR_LITERAL = re.compile(r"\bColor\(\s*(?:-?\d|[\"'])")
    DECLARATION = re.compile(
        r"^\s*(?:static\s+)?(?:const|var|@export(?:\s+var)?|@onready\s+var)\b"
    )

    def check(
        self, path: Path, source: str, root: Path
    ) -> list[Diagnostic]:
        findings: list[Diagnostic] = []
        for line_number, line in code_lines(source):
            if not self.COLOR_LITERAL.search(line):
                continue
            if self.DECLARATION.match(line):
                continue
            findings.append(
                Diagnostic(
                    path,
                    line_number,
                    1,
                    self.id,
                    "不要把 Color(...) 内联在表达式里；抽成命名常量或走 GameColors",
                    self.severity,
                )
            )
        return findings


def build_rules(root: Path) -> list[Rule]:
    return [
        CommentMarkerRule(),
        CommentedCodeRule(),
        ResourceNameRule(),
        FileAccessBoundaryRule(root),
        ModPathRule(),
        InlineColorRule(),
    ]
