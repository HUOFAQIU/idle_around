"""Claude Code PostToolUse 钩子：仅对 Godot 源码/场景/资源文件跑单文件 lint。"""

import json
import subprocess
import sys
from pathlib import Path

RELEVANT_SUFFIXES = {".gd", ".tscn", ".tres"}


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0

    file_path = (payload.get("tool_input") or {}).get("file_path")
    if not file_path:
        return 0

    # 编辑 .md / .json / .toml / .py 等非 Godot 文件直接短路返回，避免拉起 runner.py
    if Path(file_path).suffix.lower() not in RELEVANT_SUFFIXES:
        return 0

    root = Path(__file__).resolve().parents[1]
    result = subprocess.run(
        [
            sys.executable,
            "-X",
            "utf8",
            "-I",
            str(root / "tools/lint/runner.py"),
            "--root",
            str(root),
            "--file",
            str(file_path),
            "--quiet",
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )

    if result.returncode != 0:
        if result.stdout:
            print(result.stdout, end="", file=sys.stderr)
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        return 2

    if result.stdout:
        print(result.stdout, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
