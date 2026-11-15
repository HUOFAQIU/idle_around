"""轻量 GDScript 注释扫描器：只做 lint 需要的那部分词法。"""

from dataclasses import dataclass
from typing import Iterator


@dataclass(frozen=True)
class Comment:
    line: int
    column: int
    text: str


def iter_comments(source: str) -> Iterator[Comment]:
    """产出真正的注释；字符串里的 # 不算。"""
    triple: str | None = None
    for line_number, line in enumerate(source.splitlines(), 1):
        index = 0
        while index < len(line):
            if triple is not None:
                end = line.find(triple, index)
                if end < 0:
                    index = len(line)
                else:
                    index = end + 3
                    triple = None
                continue

            char = line[index]
            if char == "#":
                yield Comment(line_number, index + 1, line[index:])
                break

            if char in ("'", '"'):
                marker = char * 3
                if line.startswith(marker, index):
                    triple = marker
                    index += 3
                    continue

                index += 1
                while index < len(line):
                    if line[index] == "\\":
                        index += 2
                    elif line[index] == char:
                        index += 1
                        break
                    else:
                        index += 1
                continue

            index += 1


def code_lines(source: str) -> list[tuple[int, str]]:
    """返回去掉行尾注释后的代码行；行号保持 1 起。"""
    comments = {comment.line: comment.column for comment in iter_comments(source)}
    result: list[tuple[int, str]] = []
    for line_number, line in enumerate(source.splitlines(), 1):
        column = comments.get(line_number)
        result.append(
            (line_number, line if column is None else line[: column - 1])
        )
    return result
