"""DOC/ 自动元数据扫描与 DOC/INDEX.md 路由校验的单元测试。"""

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

    def write_doc(
        self,
        name: str,
        kind: str = "实现",
        status: str = "有效",
        date_str: str = "2026-11-24",
        *,
        body: str = "",
    ) -> None:
        path = self.root / "DOC" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        content = f"# 文档\n\n> 类型：{kind} | 状态：{status} | 核对：{date_str}\n"
        if body:
            content += "\n" + body
        path.write_text(content, encoding="utf-8")

    def write_index(self, routes: list[tuple[str, str, str]]) -> None:
        lines = [
            "# 文档索引",
            "",
            "## 需求 → 文档 / 代码",
            "",
            "| 你要做什么 | 先读 | 代码入口 |",
            "|---|---|---|",
        ]
        for task, docs, code in routes:
            lines.append(f"| {task} | {docs} | {code} |")
        (self.root / "DOC" / "INDEX.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    def test_valid_docs_and_routes_pass(self) -> None:
        self.write_doc("架构/foo.md")
        self.write_doc("指南/bar.md", kind="指南", status="有效", date_str="2026-11-23")
        (self.root / "Scripts").mkdir()
        (self.root / "Scripts" / "foo.gd").write_text("", encoding="utf-8")
        self.write_index([("测试", "`架构/foo.md`、`指南/bar.md`", "`Scripts/foo.gd`、`Scripts/*.gd`")])
        self.assertEqual(check_index(self.root), [])

    def test_unlisted_doc_is_still_checked_for_header(self) -> None:
        self.write_index([])
        bad = self.root / "DOC" / "架构" / "orphan.md"
        bad.parent.mkdir(parents=True, exist_ok=True)
        bad.write_text("# 缺头文档\n\n只有正文\n", encoding="utf-8")
        errors = check_index(self.root)
        self.assertEqual(len(errors), 1)
        self.assertIn("DOC/架构/orphan.md", errors[0])
        self.assertIn("文档头缺少", errors[0])

    def test_invalid_date_format_is_reported(self) -> None:
        self.write_doc("架构/foo.md", date_str="2026/11/24")
        self.write_index([("测试", "`架构/foo.md`", "—")])
        errors = check_index(self.root)
        self.assertEqual(len(errors), 1)
        self.assertIn("YYYY-MM-DD", errors[0])

    def test_broken_route_target_is_reported(self) -> None:
        self.write_index([("测试", "`架构/missing.md`", "—")])
        errors = check_index(self.root)
        self.assertEqual(len(errors), 1)
        self.assertIn("路由目标不存在", errors[0])

    def test_broken_code_entry_is_reported(self) -> None:
        self.write_doc("架构/foo.md")
        self.write_index([("测试", "`架构/foo.md`", "`Scripts/missing.gd`")])
        errors = check_index(self.root)
        self.assertEqual(len(errors), 1)
        self.assertIn("代码入口不存在", errors[0])

    def test_strict_budget_flags_oversized_doc(self) -> None:
        self.write_doc("架构/big.md", body="\n".join(f"line {i}" for i in range(210)))
        self.write_index([("大文档", "`架构/big.md`", "—")])
        self.assertEqual(check_index(self.root), [])
        errors = check_index(self.root, strict_budget=True)
        self.assertTrue(any("超出行数上限" in e for e in errors))

    def test_write_index_compat_returns_zero(self) -> None:
        self.write_index([])
        self.assertEqual(write_index(self.root), 0)


if __name__ == "__main__":
    unittest.main()
