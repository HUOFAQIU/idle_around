"""strip_comments 的单元测试。"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from strip_comments import _strip


class StripCommentsTest(unittest.TestCase):
    def test_removes_plain_comment(self) -> None:
        text, removed, trailing = _strip("# note\nvar a := 1\n")
        self.assertEqual(text, "var a := 1\n")
        self.assertEqual((removed, trailing), (1, 0))

    def test_keeps_inspector_doc(self) -> None:
        source = "## 说明\n@export var value: int\n"
        text, removed, trailing = _strip(source)
        self.assertEqual(text, source)
        self.assertEqual((removed, trailing), (0, 0))

    def test_keeps_provenance(self) -> None:
        text, removed, trailing = _strip("## @meta_license: MIT\n")
        self.assertEqual(text, "## @meta_license: MIT\n")
        self.assertEqual((removed, trailing), (0, 0))

    def test_keeps_hash_in_string(self) -> None:
        text, removed, trailing = _strip('var s := "# not"\n# yes\n')
        self.assertEqual(text, 'var s := "# not"\n')
        self.assertEqual((removed, trailing), (1, 0))

    def test_removes_trailing_comment(self) -> None:
        text, removed, trailing = _strip("var a := 1 # note\n")
        self.assertEqual(text, "var a := 1\n")
        self.assertEqual((removed, trailing), (0, 1))

    def test_trims_blank_edges_and_collapses_runs(self) -> None:
        text, removed, _ = _strip("\n\n# note\nvar a := 1\n\n\n\n")
        self.assertEqual(text, "var a := 1\n")
        self.assertEqual(removed, 1)


if __name__ == "__main__":
    unittest.main()
