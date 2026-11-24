"""首方代码允许保留的注释：Inspector 文档、来源标注、生成文件，以及单行 # why:/# invariant: 契约标注。"""

import re

from lexer import iter_comments

EXPORT_ANNOTATION = re.compile(r"^\s*@export")
EXPORT_NON_PROPERTY = re.compile(r"^\s*@export_(?:group|subgroup|category)\b")
PROVENANCE = re.compile(r"^##\s*@meta_(?:addon|author|license)\b")
CONTRACT_NOTE = re.compile(r"^#\s*(?:why|invariant):\s*\S")
MAX_CONTRACT_LEN = 120

GENERATED_FILES = frozenset({"godot_gas/gameplay_tags.gd"})


def is_generated(relative_path: str) -> bool:
    return relative_path in GENERATED_FILES


def allowed_comment_lines(source: str) -> set[int]:
    lines = source.splitlines()
    allowed: set[int] = set()

    for index, line in enumerate(lines):
        if not EXPORT_ANNOTATION.match(line) or EXPORT_NON_PROPERTY.match(line):
            continue
        cursor = index - 1
        while cursor >= 0 and lines[cursor].strip().startswith("##"):
            allowed.add(cursor + 1)
            cursor -= 1

    for comment in iter_comments(source):
        if PROVENANCE.match(comment.text):
            allowed.add(comment.line)
            continue
        if CONTRACT_NOTE.match(comment.text) and len(comment.text) <= MAX_CONTRACT_LEN:
            allowed.add(comment.line)
            continue
        prefix = lines[comment.line - 1][: comment.column - 1]
        if (
            prefix.strip()
            and EXPORT_ANNOTATION.match(prefix)
            and not EXPORT_NON_PROPERTY.match(prefix)
        ):
            allowed.add(comment.line)

    return allowed
