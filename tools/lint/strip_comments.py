"""按注释策略删除首方 GDScript 注释。

用法：
    python -I tools/lint/strip_comments.py --dry-run
    python -I tools/lint/strip_comments.py --check
    python -I tools/lint/strip_comments.py --write
    python -I tools/lint/strip_comments.py --write Scripts game
"""

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from comment_policy import allowed_comment_lines, is_generated
from lexer import iter_comments
from runner import FIRST_PARTY_ROOTS


@dataclass
class Change:
    path: Path
    removed: int
    trailing: int


def _collect(root: Path, given: list[str]) -> list[Path]:
    targets = given or list(FIRST_PARTY_ROOTS)
    files: list[Path] = []
    for raw in targets:
        path = Path(raw)
        if not path.is_absolute():
            path = root / path
        if path.is_dir():
            files.extend(path.rglob("*.gd"))
        elif path.suffix.lower() == ".gd":
            files.append(path)
    return sorted(set(files))


def _strip(source: str) -> tuple[str, int, int]:
    lines = source.splitlines()
    comments = {item.line: item for item in iter_comments(source)}
    allowed = allowed_comment_lines(source)
    kept: list[str] = []
    removed = 0
    trailing = 0
    for number, line in enumerate(lines, 1):
        comment = comments.get(number)
        if comment is None or number in allowed:
            kept.append(line)
            continue
        prefix = line[: comment.column - 1]
        if prefix.strip():
            kept.append(prefix.rstrip())
            trailing += 1
            continue
        removed += 1

    while kept and not kept[0].strip():
        kept.pop(0)
    while kept and not kept[-1].strip():
        kept.pop()

    collapsed: list[str] = []
    blank_run = 0
    for line in kept:
        if line.strip():
            blank_run = 0
        else:
            blank_run += 1
            if blank_run > 2:
                continue
        collapsed.append(line)

    text = "\n".join(collapsed)
    if source.endswith("\n"):
        text += "\n"
    return text, removed, trailing


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--write", action="store_true")
    parser.add_argument("paths", nargs="*")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    changes: list[Change] = []
    for path in _collect(root, args.paths):
        relative = path.resolve().relative_to(root).as_posix()
        if is_generated(relative):
            continue
        source = path.read_text(encoding="utf-8")
        stripped, removed, trailing = _strip(source)
        if removed or trailing:
            changes.append(Change(path, removed, trailing))
            if args.write:
                with path.open("w", encoding="utf-8", newline="\n") as handle:
                    handle.write(stripped)

    total_lines = sum(item.removed for item in changes)
    total_trailing = sum(item.trailing for item in changes)
    for change in changes:
        shown = change.path.resolve().relative_to(root).as_posix()
        if not args.check:
            print(f"{shown}: 删除 {change.removed} 行，行尾 {change.trailing} 处")
    print(
        f"共 {len(changes)} 个文件：删除 {total_lines} 行，行尾 {total_trailing} 处"
    )
    if args.check and total_lines + total_trailing:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
