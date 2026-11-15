"""Lint 诊断数据结构。"""

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Diagnostic:
    path: Path
    line: int
    column: int
    rule_id: str
    message: str
    severity: str = "error"

    def format(self, root: Path) -> str:
        try:
            shown = self.path.relative_to(root)
        except ValueError:
            shown = self.path
        return (
            f"{shown}:{self.line}:{self.column}: "
            f"[{self.rule_id}] {self.message}"
        )
