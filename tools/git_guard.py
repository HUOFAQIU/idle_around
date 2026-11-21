import json
import re
import sys

DANGEROUS_PATTERNS = (
    (
        re.compile(
            r"\bgit\s+push\b[^\n]*(?:(?<!\S)--force(?:-with-lease)?"
            r"|(?<!\S)-[A-Za-z]*f[A-Za-z]*(?!\S)|\s\+\S+)"
        ),
        "git push --force 会改写远端历史",
    ),
    (
        re.compile(r"\bgit\s+reset\b[^\n]*(?<!\S)--hard(?!\S)"),
        "git reset --hard 会丢弃未提交改动",
    ),
    (
        re.compile(
            r"\bgit\s+clean\b[^\n]*(?:(?<!\S)--force|(?<!\S)-[A-Za-z]*f[A-Za-z]*(?!\S))"
        ),
        "git clean -f 会删除未跟踪文件",
    ),
    (
        re.compile(
            r"\bgit\s+branch\b[^\n]*(?:(?<!\S)-D(?:\s|$)"
            r"|(?<!\S)--force(?!\S)[^\n]*(?<!\S)--delete(?!\S)"
            r"|(?<!\S)--delete(?!\S)[^\n]*(?<!\S)--force(?!\S))"
        ),
        "git branch -D 会强制删除分支",
    ),
    (
        re.compile(r"\bgit\s+checkout\b[^\n]*(?<!\S)--(?:\s|$)"),
        "git checkout -- 会丢弃工作区改动",
    ),
    (
        re.compile(r"\bgit\s+checkout\s+\.(?:/|\s|$)"),
        "git checkout . 会丢弃工作区改动",
    ),
    (
        re.compile(r"\bgit\s+restore\b[^\n]*(?<!\S)(?:--worktree|-W)(?!\S)"),
        "git restore --worktree 会丢弃工作区改动",
    ),
    (
        re.compile(r"\bgit\s+restore\b(?![^\n]*(?<!\S)--staged(?!\S))"),
        "git restore 会丢弃工作区改动",
    ),
)


def find_danger(command):
    for pattern, reason in DANGEROUS_PATTERNS:
        if pattern.search(command):
            return reason
    return None


def main():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return 0
    if not isinstance(payload, dict):
        return 0
    tool_input = payload.get("tool_input")
    command = tool_input.get("command", "") if isinstance(tool_input, dict) else ""
    if not isinstance(command, str):
        return 0
    reason = find_danger(command)
    if reason is None:
        return 0
    print(f"[git-guard] 已阻止：{reason}。如确需执行，请手动运行。", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
