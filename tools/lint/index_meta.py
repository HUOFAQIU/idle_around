"""检查 DOC/INDEX.md 的文档清单与文档头元数据是否一致。"""

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

META_SECTION = "## 文档清单"
ROW_RE = re.compile(
    r"^\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*$"
)
META_RE = re.compile(r"(类型|状态|核对|整理)[：:]\s*([^|\n]+)")


@dataclass
class IndexRow:
    line: int
    path: str
    kind: str
    status: str
    date: str


def read_rows(index_path: Path) -> list[IndexRow]:
    rows: list[IndexRow] = []
    in_section = False
    for number, line in enumerate(index_path.read_text(encoding="utf-8").splitlines(), 1):
        if line.startswith("## "):
            in_section = line.strip() == META_SECTION
            continue
        if not in_section:
            continue
        match = ROW_RE.match(line)
        if not match or match.group(1) == "文档":
            continue
        path, kind, status, date = (part.strip() for part in match.groups())
        rows.append(IndexRow(number, path, kind, status, date))
    return rows


def read_header(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines()[:15]:
        for key, value in META_RE.findall(line):
            values.setdefault(key, value.strip())
    return values


def _type_matches(index_value: str, header_value: str) -> bool:
    return index_value in [part.strip() for part in header_value.split("/")]


def _status_base(value: str) -> str:
    return value.split("（", 1)[0].split("(", 1)[0].strip()


def _status_matches(index_value: str, header_value: str) -> bool:
    return _status_base(index_value) == _status_base(header_value)


def _format_row(row: IndexRow) -> str:
    return f"| `{row.path}` | {row.kind} | {row.status} | {row.date} |"


def check_index(root: Path) -> list[str]:
    doc_root = root / "DOC"
    errors: list[str] = []
    for row in read_rows(doc_root / "INDEX.md"):
        if not row.path.endswith(".md"):
            continue
        path = doc_root / row.path
        if not path.is_file():
            errors.append(f"DOC/INDEX.md:{row.line}: 文档不存在：{row.path}")
            continue
        header = read_header(path)
        kind = header.get("类型")
        status = header.get("状态")
        date = header.get("核对") or header.get("整理")
        missing = [
            name
            for name, value in (("类型", kind), ("状态", status), ("核对/整理", date))
            if not value
        ]
        if missing:
            errors.append(
                f"DOC/INDEX.md:{row.line}: `{row.path}` 文档头缺少 {'、'.join(missing)}"
            )
            continue
        if not _type_matches(row.kind, kind):
            errors.append(
                f"DOC/INDEX.md:{row.line}: `{row.path}` 类型 INDEX={row.kind} 文档头={kind}"
            )
        if not _status_matches(row.status, status):
            errors.append(
                f"DOC/INDEX.md:{row.line}: `{row.path}` 状态 INDEX={row.status} 文档头={status}"
            )
        if row.date != date:
            errors.append(
                f"DOC/INDEX.md:{row.line}: `{row.path}` 日期 INDEX={row.date} 文档头={date}"
            )
    return errors


def write_index(root: Path) -> int:
    doc_root = root / "DOC"
    index_path = doc_root / "INDEX.md"
    lines = index_path.read_text(encoding="utf-8").splitlines()
    changed = 0
    for row in read_rows(index_path):
        if not row.path.endswith(".md"):
            continue
        path = doc_root / row.path
        if not path.is_file():
            continue
        header = read_header(path)
        kind = header.get("类型")
        status = header.get("状态")
        date = header.get("核对") or header.get("整理")
        if not kind or not status or not date:
            continue
        next_row = IndexRow(
            row.line,
            row.path,
            row.kind if _type_matches(row.kind, kind) else kind.split("/")[0].strip(),
            row.status if _status_matches(row.status, status) else status,
            date,
        )
        if next_row == row:
            continue
        lines[row.line - 1] = _format_row(next_row)
        changed += 1
    if changed:
        index_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return changed


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description="检查 DOC/INDEX.md 元数据")
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    if args.write:
        print(f"INDEX_META_WRITTEN {write_index(root)}")
    errors = check_index(root)
    for error in errors:
        print(error)
    if errors:
        print(f"\nINDEX_META_FAILED {len(errors)}")
        return 1
    print(f"INDEX_META_OK {len(read_rows(root / 'DOC' / 'INDEX.md'))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
