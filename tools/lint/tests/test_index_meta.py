"""DOC/INDEX.md 元数据检查的单元测试。"""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from index_meta import check_index, write_index


class IndexMetaTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / "DOC").mkdir()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def write_doc(self, name: str, kind: str, status: str, date: str) -> None:
        path = self.root / "DOC" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            f"# 文档\n\n> 类型：{kind} | 状态：{status} | 核对：{date}\n",
            encoding="utf-8",
        )

    def write_index(self, rows: list[tuple[str, str, str, str]]) -> None:
        body = ["# 索引", "", "## 文档清单", "", "| 文档 | 类型 | 状态 | 日期 |", "|---|---|---|---|"]
        body.extend(f"| `{path}` | {kind} | {status} | {date} |" for path, kind, status, date in rows)
        (self.root / "DOC" / "INDEX.md").write_text("\n".join(body) + "\n", encoding="utf-8")

    def test_matching_row_has_no_error(self) -> None:
        self.write_doc("foo.md", "实现", "有效", "2026-11-21")
        self.write_index([("foo.md", "实现", "有效", "2026-11-21")])
        self.assertEqual(check_index(self.root), [])

    def test_type_set_matches_single_index_type(self) -> None:
        self.write_doc("foo.md", "设计 / 实现", "有效", "2026-11-21")
        self.write_index([("foo.md", "设计", "有效", "2026-11-21")])
        self.assertEqual(check_index(self.root), [])

    def test_status_suffix_is_allowed(self) -> None:
        self.write_doc("foo.md", "设计", "部分实现", "2026-11-21")
        self.write_index([("foo.md", "设计", "部分实现（内置 core 已接入）", "2026-11-21")])
        self.assertEqual(check_index(self.root), [])

    def test_date_mismatch_is_reported(self) -> None:
        self.write_doc("foo.md", "实现", "有效", "2026-11-21")
        self.write_index([("foo.md", "实现", "有效", "2026-11-18")])
        errors = check_index(self.root)
        self.assertEqual(len(errors), 1)
        self.assertIn("日期", errors[0])

    def test_missing_doc_is_reported(self) -> None:
        self.write_index([("foo.md", "实现", "有效", "2026-11-21")])
        errors = check_index(self.root)
        self.assertEqual(len(errors), 1)
        self.assertIn("文档不存在", errors[0])

    def test_write_syncs_date_and_preserves_status_suffix(self) -> None:
        self.write_doc("foo.md", "设计", "部分实现", "2026-11-21")
        self.write_index([("foo.md", "设计", "部分实现（内置 core 已接入）", "2026-11-18")])
        self.assertEqual(write_index(self.root), 1)
        self.assertEqual(check_index(self.root), [])
        text = (self.root / "DOC" / "INDEX.md").read_text(encoding="utf-8")
        self.assertIn("部分实现（内置 core 已接入）", text)
        self.assertIn("2026-11-21", text)


if __name__ == "__main__":
    unittest.main()
