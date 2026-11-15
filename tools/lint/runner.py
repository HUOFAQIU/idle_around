"""idle_around 的 lint 入口。"""

import argparse
import subprocess
import sys
import tomllib
from dataclasses import dataclass
from datetime import date
from fnmatch import fnmatch
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from diagnostics import Diagnostic
from rules import Rule, build_rules

FIRST_PARTY_ROOTS = (
    "Scripts",
    "Main",
    "game",
    "godot_gas",
    "Windows",
    "modkit",
)
RELEVANT_SUFFIXES = {".gd", ".tscn", ".tres"}
ALLOWLIST_PATH = Path(__file__).resolve().parent / "allowlist.toml"


@dataclass
class AllowEntry:
    rule: str
    path: str
    reason: str
    expires: date
    used: bool = False


def _is_first_party(root: Path, path: Path) -> bool:
    try:
        relative = path.resolve().relative_to(root.resolve())
    except ValueError:
        return False
    return bool(relative.parts) and relative.parts[0] in FIRST_PARTY_ROOTS


def _collect_all(root: Path) -> list[Path]:
    files: list[Path] = []
    for name in FIRST_PARTY_ROOTS:
        base = root / name
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            if path.is_file() and path.suffix.lower() in RELEVANT_SUFFIXES:
                files.append(path)
    return sorted(files)


def _collect_staged(root: Path) -> list[Path]:
    result = subprocess.run(
        [
            "git",
            "-C",
            str(root),
            "diff",
            "--cached",
            "--name-only",
            "--diff-filter=ACMR",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "git diff 失败")

    files: list[Path] = []
    for line in result.stdout.splitlines():
        path = root / line
        if (
            path.is_file()
            and path.suffix.lower() in RELEVANT_SUFFIXES
            and _is_first_party(root, path)
        ):
            files.append(path)
    return sorted(set(files))


def _collect_given(root: Path, paths: list[str]) -> list[Path]:
    files: list[Path] = []
    for raw in paths:
        path = Path(raw)
        if not path.is_absolute():
            candidate = root / path
            path = candidate if candidate.exists() else Path.cwd() / path
        if (
            path.is_file()
            and path.suffix.lower() in RELEVANT_SUFFIXES
            and _is_first_party(root, path)
        ):
            files.append(path)
    return sorted(set(files))


def _load_allowlist() -> tuple[list[AllowEntry], list[Diagnostic]]:
    entries: list[AllowEntry] = []
    errors: list[Diagnostic] = []
    if not ALLOWLIST_PATH.is_file():
        return entries, errors

    data = tomllib.loads(ALLOWLIST_PATH.read_text(encoding="utf-8"))
    for item in data.get("allow", []):
        rule = str(item.get("rule", "")).strip()
        pattern = str(item.get("path", "")).strip()
        reason = str(item.get("reason", "")).strip()
        expires_raw = str(item.get("expires", "")).strip()
        if not rule or not pattern or not reason or not expires_raw:
            errors.append(
                Diagnostic(
                    ALLOWLIST_PATH,
                    1,
                    1,
                    "allowlist-invalid",
                    "例外必须同时写 rule、path、reason、expires",
                )
            )
            continue
        try:
            expires = date.fromisoformat(expires_raw)
        except ValueError:
            errors.append(
                Diagnostic(
                    ALLOWLIST_PATH,
                    1,
                    1,
                    "allowlist-invalid",
                    f"expires 不是 YYYY-MM-DD：{expires_raw}",
                )
            )
            continue
        if expires < date.today():
            errors.append(
                Diagnostic(
                    ALLOWLIST_PATH,
                    1,
                    1,
                    "allowlist-expired",
                    f"例外已过期：{rule} {pattern}",
                )
            )
            continue
        entries.append(AllowEntry(rule, pattern, reason, expires))
    return entries, errors


def _apply_allowlist(
    diagnostics: list[Diagnostic], entries: list[AllowEntry], root: Path
) -> list[Diagnostic]:
    kept: list[Diagnostic] = []
    for diagnostic in diagnostics:
        try:
            relative = diagnostic.path.resolve().relative_to(root.resolve()).as_posix()
        except ValueError:
            kept.append(diagnostic)
            continue

        matched = False
        for entry in entries:
            if (
                not entry.used
                and entry.rule == diagnostic.rule_id
                and fnmatch(relative, entry.path)
            ):
                entry.used = True
                matched = True
                break
        if not matched:
            kept.append(diagnostic)

    for entry in entries:
        if not entry.used:
            kept.append(
                Diagnostic(
                    ALLOWLIST_PATH,
                    1,
                    1,
                    "allowlist-unused",
                    f"例外没有命中，删除它：{entry.rule} {entry.path}",
                )
            )
    return kept


def _check_file(rule: Rule, path: Path, root: Path) -> list[Diagnostic]:
    try:
        source = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        return [
            Diagnostic(path, 1, 1, "read-error", f"读取失败：{error}")
        ]
    return rule.check(path, source, root)


def _collect_files(root: Path, args: argparse.Namespace) -> list[Path]:
    if args.file:
        return _collect_given(root, args.file)
    if args.staged:
        return _collect_staged(root)
    return _collect_all(root)


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")

    parser = argparse.ArgumentParser(description="idle_around lint")
    parser.add_argument(
        "--root", default=str(Path(__file__).resolve().parents[2])
    )
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--staged", action="store_true")
    parser.add_argument("--file", action="append", default=[])
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--list-rules", action="store_true")
    args = parser.parse_args(argv)

    root = Path(args.root).resolve()
    rules = build_rules(root)

    if args.list_rules:
        for rule in rules:
            print(f"{rule.id}: {rule.description} ({rule.severity})")
        return 0

    files = _collect_files(root, args)
    if not files:
        if not args.quiet:
            print("没有需要检查的文件")
        return 0

    diagnostics: list[Diagnostic] = []
    for path in files:
        for rule in rules:
            if rule.applies_to(path):
                diagnostics.extend(_check_file(rule, path, root))

    entries, allow_errors = _load_allowlist()
    diagnostics = allow_errors + _apply_allowlist(
        diagnostics, entries, root
    )
    diagnostics.sort(
        key=lambda item: (
            str(item.path).lower(),
            item.line,
            item.column,
            item.rule_id,
        )
    )

    errors = 0
    warnings = 0
    for diagnostic in diagnostics:
        print(diagnostic.format(root))
        if diagnostic.severity == "error":
            errors += 1
        else:
            warnings += 1

    if not args.quiet:
        print(f"\n检查 {len(files)} 个文件：{errors} 个错误，{warnings} 个警告")
    if errors:
        return 1
    if warnings and args.strict:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
