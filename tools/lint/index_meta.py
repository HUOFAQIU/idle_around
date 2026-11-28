"""自动扫描 docs/**/*.md 元数据，并校验 docs/INDEX.md 路由表路径有效性。"""

import argparse
import re
import sys
from datetime import date
from pathlib import Path

META_RE = re.compile(r"(类型|状态|核对|整理)[：:]\s*([^|\n]+)")
ROUTE_DOC_RE = re.compile(r"`([^`\s]+\.md)`")
ROUTE_CODE_RE = re.compile(r"`([^`\s]+)`")
DRIVE_RE = re.compile(r"^[A-Za-z]:")
HEADER_SCAN_LINES = 15
DEFAULT_MAX_LINES = 200
DEFAULT_MAX_BYTES = 12 * 1024


def looks_like_path(ref: str) -> bool:
    """判断「代码入口」列的内联代码是否像路径：含路径分隔符或末段带扩展名，`::` 符号引用不算。"""
    if "::" in ref:
        return False
    return "/" in ref or "\\" in ref or "." in ref.rsplit("/", 1)[-1]


def is_repo_relative(ref: str) -> bool:
    """路由引用必须是仓库相对路径，排除绝对路径、盘符与 `..` 回溯。"""
    if ref.startswith(("/", "\\")) or DRIVE_RE.match(ref):
        return False
    return ".." not in ref.replace("\\", "/").split("/")


def iter_docs(doc_root: Path) -> list[Path]:
    """返回 docs/ 下除 INDEX.md 外的全部 Markdown 文档（按 POSIX 路径排序）。"""
    if not doc_root.is_dir():
        return []
    docs = [
        path
        for path in doc_root.rglob("*.md")
        if path.is_file() and path.resolve() != (doc_root / "INDEX.md").resolve()
    ]
    return sorted(docs, key=lambda p: p.relative_to(doc_root).as_posix())


def read_header(path: Path) -> dict[str, str]:
    """提取文档前 15 行中的元数据字段（类型/状态/核对/整理）。"""
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines()[:HEADER_SCAN_LINES]:
        for key, value in META_RE.findall(line):
            values.setdefault(key, value.strip())
    return values


def read_route_refs(index_path: Path) -> list[tuple[int, str]]:
    """提取 docs/INDEX.md 路由表中引用的所有相对 .md 路径。"""
    refs: list[tuple[int, str]] = []
    if not index_path.is_file():
        return refs
    in_table = False
    for number, line in enumerate(index_path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("## "):
            in_table = "需求" in stripped or "路由" in stripped
            continue
        if not in_table or not stripped.startswith("|"):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if len(cells) < 2 or cells[0] == "你要做什么" or set(cells[0]) <= {"-"}:
            continue
        # 第 2 列为「先读」文档列
        for ref in ROUTE_DOC_RE.findall(cells[1]):
            refs.append((number, ref))
    return refs


def read_route_code_refs(index_path: Path) -> list[tuple[int, str]]:
    """提取 docs/INDEX.md 路由表第 3 列「代码入口」中的文件/目录路径。"""
    refs: list[tuple[int, str]] = []
    if not index_path.is_file():
        return refs
    in_table = False
    for number, line in enumerate(index_path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("## "):
            in_table = "需求" in stripped or "路由" in stripped
            continue
        if not in_table or not stripped.startswith("|"):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if len(cells) < 3 or cells[0] == "你要做什么" or set(cells[0]) <= {"-"}:
            continue
        for ref in ROUTE_CODE_RE.findall(cells[2]):
            if "*" in ref or not looks_like_path(ref):
                continue
            refs.append((number, ref))
    return refs


def check_index(
    root: Path,
    *,
    strict_budget: bool = False,
    max_lines: int = DEFAULT_MAX_LINES,
    max_bytes: int = DEFAULT_MAX_BYTES,
) -> list[str]:
    """校验所有文档头元数据、日期格式以及 INDEX.md 路由路径有效性。"""
    doc_root = root / "docs"
    index_path = doc_root / "INDEX.md"
    errors: list[str] = []

    if not index_path.is_file():
        errors.append("docs/INDEX.md: 缺少文档入口文件")
    else:
        for line_no, ref in read_route_refs(index_path):
            if not is_repo_relative(ref):
                errors.append(f"docs/INDEX.md:{line_no}: 路由目标必须是仓库相对路径：{ref}")
                continue
            target = doc_root / ref
            if not target.is_file():
                errors.append(f"docs/INDEX.md:{line_no}: 路由目标不存在：{ref}")
        for line_no, ref in read_route_code_refs(index_path):
            if not is_repo_relative(ref):
                errors.append(f"docs/INDEX.md:{line_no}: 代码入口必须是仓库相对路径：{ref}")
                continue
            target = root / ref
            if not target.exists():
                errors.append(f"docs/INDEX.md:{line_no}: 代码入口不存在：{ref}")

    for path in iter_docs(doc_root):
        rel = path.relative_to(doc_root).as_posix()
        header = read_header(path)
        kind = header.get("类型")
        status = header.get("状态")
        checked_date = header.get("核对") or header.get("整理")
        missing = [
            name
            for name, value in (("类型", kind), ("状态", status), ("核对/整理", checked_date))
            if not value
        ]
        if missing:
            errors.append(f"docs/{rel}: 文档头缺少 {'、'.join(missing)}")
            continue
        try:
            date.fromisoformat(checked_date)
        except ValueError:
            errors.append(f"docs/{rel}: 核对/整理日期格式不是 YYYY-MM-DD：{checked_date}")

        if strict_budget:
            raw = path.read_bytes()
            line_count = raw.decode("utf-8").count("\n") + (0 if raw.endswith(b"\n") else 1)
            if line_count > max_lines:
                errors.append(f"docs/{rel}: 超出行数上限 ({line_count} > {max_lines})")
            if len(raw) > max_bytes:
                errors.append(f"docs/{rel}: 超出体积上限 ({len(raw)}B > {max_bytes}B)")

    return errors


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")

    parser = argparse.ArgumentParser(description="自动扫描 docs/ 元数据并校验 docs/INDEX.md 路由")
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument("--strict-budget", action="store_true", help="同时校验单篇文档行数与字节预算")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    errors = check_index(root, strict_budget=args.strict_budget)
    for error in errors:
        print(error)
    if errors:
        print(f"\nINDEX_META_FAILED {len(errors)}")
        return 1

    doc_count = len(iter_docs(root / "docs"))
    print(f"INDEX_META_OK {doc_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
