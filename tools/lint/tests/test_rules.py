"""lint 规则的单元测试。"""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lexer import code_lines, iter_comments
from rules import (
    FileAccessBoundaryRule,
    InlineColorRule,
    ModPathRule,
    NoCommentsRule,
    ResourceNameRule,
)


class LexerTest(unittest.TestCase):
    def test_hash_in_strings_is_not_comment(self) -> None:
        source = 'var a := "# TODO"\nvar b := \'#\'\n# real\n'
        comments = list(iter_comments(source))
        self.assertEqual([(item.line, item.text) for item in comments], [(3, "# real")])

    def test_triple_quoted_string(self) -> None:
        source = 'var a := """\n# not a comment\n"""\n# real\n'
        comments = list(iter_comments(source))
        self.assertEqual([(item.line, item.text) for item in comments], [(4, "# real")])

    def test_escaped_quote(self) -> None:
        source = 'var a := "quote \\" # not comment"\n# real\n'
        comments = list(iter_comments(source))
        self.assertEqual([(item.line, item.text) for item in comments], [(2, "# real")])

    def test_code_lines_strips_comment(self) -> None:
        lines = code_lines("var a := 1 # note\n")
        self.assertEqual(lines, [(1, "var a := 1 ")])


class NoCommentsRuleTest(unittest.TestCase):
    def setUp(self) -> None:
        self.rule = NoCommentsRule()

    def check(self, source: str, path: str = "Scripts/example.gd") -> list:
        return self.rule.check(Path(path), source, Path("."))

    def test_flags_plain_comment(self) -> None:
        self.assertEqual(len(self.check("# 这里说明数据流\n")), 1)

    def test_flags_doc_comment_outside_inspector(self) -> None:
        self.assertEqual(len(self.check("## 类说明\nvar value\n")), 1)

    def test_flags_region(self) -> None:
        self.assertEqual(len(self.check("#region 查询\n")), 1)

    def test_flags_trailing_comment(self) -> None:
        self.assertEqual(len(self.check("var a := 1 # 说明\n")), 1)

    def test_allows_inspector_doc(self) -> None:
        source = "## Inspector 说明\n@export var value: int\n"
        self.assertEqual(self.check(source), [])

    def test_allows_inspector_doc_on_export_range(self) -> None:
        source = "## 范围说明\n@export_range(0, 10) var value: int\n"
        self.assertEqual(self.check(source), [])

    def test_allows_inline_inspector_doc(self) -> None:
        source = "@export var value: int ## 行尾说明\n"
        self.assertEqual(self.check(source), [])

    def test_allows_provenance(self) -> None:
        self.assertEqual(self.check("## @meta_license: MIT\n"), [])

    def test_ignores_comment_in_string(self) -> None:
        self.assertEqual(self.check('var text := "# TODO"\n'), [])

    def test_ignores_generated_file(self) -> None:
        self.assertEqual(
            self.check("## AUTO-GENERATED\n", "godot_gas/gameplay_tags.gd"), []
        )


class ResourceNameRuleTest(unittest.TestCase):
    def setUp(self) -> None:
        self.rule = ResourceNameRule()

    def test_flags_chinese_name(self) -> None:
        findings = self.rule.check(
            Path("Scripts/example.tres"),
            'resource_name = "中文名"\n',
            Path("."),
        )
        self.assertEqual(len(findings), 1)

    def test_allows_english_name(self) -> None:
        findings = self.rule.check(
            Path("Scripts/example.tres"),
            'resource_name = "Example"\n',
            Path("."),
        )
        self.assertEqual(findings, [])

    def test_ignores_comment_in_gd(self) -> None:
        findings = self.rule.check(
            Path("Scripts/example.gd"),
            '# resource_name = "中文名"\n',
            Path("."),
        )
        self.assertEqual(findings, [])


class FileAccessBoundaryRuleTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.rule = FileAccessBoundaryRule(self.root)

    def test_flags_outside_allowed_dirs(self) -> None:
        path = self.root / "Scripts/example.gd"
        findings = self.rule.check(
            path, "var file := FileAccess.open(path, FileAccess.READ)\n", self.root
        )
        self.assertEqual(len(findings), 1)

    def test_allows_save_dir(self) -> None:
        path = self.root / "Scripts/save/example.gd"
        findings = self.rule.check(
            path, "var file := FileAccess.open(path, FileAccess.READ)\n", self.root
        )
        self.assertEqual(findings, [])

    def test_allows_modkit(self) -> None:
        path = self.root / "EngineTools/modkit/example.gd"
        findings = self.rule.check(
            path, "var file := FileAccess.open(path, FileAccess.READ)\n", self.root
        )
        self.assertEqual(findings, [])

    def test_ignores_comment(self) -> None:
        path = self.root / "Scripts/example.gd"
        findings = self.rule.check(
            path, "# FileAccess 只允许在存档层\n", self.root
        )
        self.assertEqual(findings, [])


class ModPathRuleTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.rule = ModPathRule()

    def test_flags_root_literal(self) -> None:
        path = self.root / "Scripts/example.gd"
        findings = self.rule.check(
            path, 'const MODS_DIR := "user://mods"\n', self.root
        )
        self.assertEqual(len(findings), 1)

    def test_flags_format_literal(self) -> None:
        path = self.root / "Scripts/example.gd"
        findings = self.rule.check(
            path, 'return "res://base_mods/%s/" % mod_id\n', self.root
        )
        self.assertEqual(len(findings), 1)

    def test_allows_specific_resource(self) -> None:
        path = self.root / "Scripts/example.gd"
        findings = self.rule.check(
            path,
            'const EFFECT := preload("res://base_mods/core/effects/burn.tres")\n',
            self.root,
        )
        self.assertEqual(findings, [])

    def test_allows_canonical_file(self) -> None:
        path = self.root / "Scripts/mod/mod_paths.gd"
        findings = self.rule.check(
            path, 'const MODS_DIR := "user://mods"\n', self.root
        )
        self.assertEqual(findings, [])

    def test_allows_modkit(self) -> None:
        path = self.root / "EngineTools/modkit/pack.gd"
        findings = self.rule.check(
            path, 'const MODS_DIR := "user://mods"\n', self.root
        )
        self.assertEqual(findings, [])

    def test_ignores_comment(self) -> None:
        path = self.root / "Scripts/example.gd"
        findings = self.rule.check(
            path, '# 路径是 "user://mods"\n', self.root
        )
        self.assertEqual(findings, [])


class InlineColorRuleTest(unittest.TestCase):
    def setUp(self) -> None:
        self.rule = InlineColorRule()

    def test_allows_named_constant(self) -> None:
        findings = self.rule.check(
            Path("Scripts/example.gd"),
            "const BG : Color = Color(0.1, 0.1, 0.1, 1.0)\n",
            Path("."),
        )
        self.assertEqual(findings, [])

    def test_flags_assignment(self) -> None:
        findings = self.rule.check(
            Path("Scripts/example.gd"),
            "style.bg_color = Color(0.1, 0.1, 0.1, 1.0)\n",
            Path("."),
        )
        self.assertEqual(len(findings), 1)

    def test_flags_call_argument(self) -> None:
        findings = self.rule.check(
            Path("Scripts/example.gd"),
            "draw_rect(rect, Color(0.1, 0.1, 0.1, 1.0), true)\n",
            Path("."),
        )
        self.assertEqual(len(findings), 1)

    def test_allows_copy_constructor(self) -> None:
        findings = self.rule.check(
            Path("Scripts/example.gd"),
            "style.bg_color = Color(style.bg_color, 1.0)\n",
            Path("."),
        )
        self.assertEqual(findings, [])

    def test_allows_export_default(self) -> None:
        findings = self.rule.check(
            Path("Scripts/example.gd"),
            '@export var accent: Color = Color("#4fb8ff")\n',
            Path("."),
        )
        self.assertEqual(findings, [])


if __name__ == "__main__":
    unittest.main()
