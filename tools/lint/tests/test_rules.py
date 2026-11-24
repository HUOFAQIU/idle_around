"""lint 规则的单元测试。"""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from boundaries import DependencyBoundaryRule
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

    def test_allows_why_and_invariant_contract_notes(self) -> None:
        self.assertEqual(self.check("# why: DWM 延迟 3 帧收缩防残影\n"), [])
        self.assertEqual(self.check("# invariant: advance_status 必须在 advance_charge 之后\n"), [])

    def test_flags_overlong_or_empty_contract_note(self) -> None:
        self.assertEqual(len(self.check("# why:\n")), 1)
        self.assertEqual(len(self.check("# why: " + "x" * 120 + "\n")), 1)

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


class DependencyBoundaryRuleTest(unittest.TestCase):
    CONFIG = """
[[layer]]
name = "domain"
paths = ["game/"]
reads = ["Scripts/game_colors.gd"]

[[layer]]
name = "content-def"
paths = ["game/content/"]
reads = ["Scripts/"]

[[layer]]
name = "script"
paths = ["Scripts/"]
reads = []

[autoload]
Warehouse = "Scripts/warehouse.gd"
"""

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "project.godot").write_text(
            '[autoload]\n\nWarehouse="*res://Scripts/warehouse.gd"\n',
            encoding="utf-8",
        )
        self.config = self.root / "boundaries.toml"
        self.config.write_text(self.CONFIG, encoding="utf-8")
        self.write("Scripts/warehouse.gd", "")
        self.write("Scripts/soul.gd", "class_name SoulData\n")
        self.write("Scripts/game_colors.gd", "")
        self.rule = DependencyBoundaryRule(self.root, self.config)

    def write(self, relative: str, source: str) -> Path:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source, encoding="utf-8")
        return path

    def check(self, relative: str, source: str) -> list:
        path = self.write(relative, source)
        return self.rule.check(path, source, self.root)

    def test_flags_res_literal_across_layers(self) -> None:
        findings = self.check(
            "game/battle/a.gd",
            'const W := preload("res://Scripts/warehouse.gd")\n',
        )
        self.assertEqual(len(findings), 1)
        self.assertIn("Scripts/warehouse.gd", findings[0].message)

    def test_flags_class_reference_across_layers(self) -> None:
        findings = self.check("game/battle/a.gd", "var soul: SoulData\n")
        self.assertEqual(len(findings), 1)
        self.assertIn("Scripts/soul.gd", findings[0].message)

    def test_flags_autoload_reference(self) -> None:
        findings = self.check(
            "game/battle/a.gd", "Warehouse.add_item(null)\n"
        )
        self.assertEqual(len(findings), 1)
        self.assertIn("Scripts/warehouse.gd", findings[0].message)

    def test_allows_same_layer(self) -> None:
        findings = self.check(
            "game/battle/a.gd",
            'const B := preload("res://game/battle/b.gd")\n',
        )
        self.assertEqual(findings, [])

    def test_allows_declared_target(self) -> None:
        findings = self.check(
            "game/battle/a.gd",
            'const C := preload("res://Scripts/game_colors.gd")\n',
        )
        self.assertEqual(findings, [])

    def test_allows_unconfigured_target(self) -> None:
        findings = self.check(
            "game/battle/a.gd",
            'const A := preload("res://Assets/icon.png")\n',
        )
        self.assertEqual(findings, [])

    def test_longest_prefix_wins(self) -> None:
        findings = self.check(
            "game/content/a.gd",
            'const W := preload("res://Scripts/soul.gd")\n',
        )
        self.assertEqual(findings, [])

    def test_flags_unassigned_source(self) -> None:
        findings = self.check("other/a.gd", "")
        self.assertEqual(len(findings), 1)
        self.assertIn("不属于任何层", findings[0].message)

    def test_ignores_class_name_in_string(self) -> None:
        findings = self.check(
            "game/battle/a.gd", 'var label := "SoulData"\n'
        )
        self.assertEqual(findings, [])

    def test_one_diagnostic_per_target(self) -> None:
        findings = self.check(
            "game/battle/a.gd",
            'const A := preload("res://Scripts/soul.gd")\n'
            'const B := preload("res://Scripts/soul.gd")\n',
        )
        self.assertEqual(len(findings), 1)
        self.assertIn("2 处引用", findings[0].message)

    def test_autoload_drift(self) -> None:
        self.config.write_text(
            self.CONFIG.replace(
                'Warehouse = "Scripts/warehouse.gd"',
                'Warehouse = "Scripts/warehouse.gd"\n'
                'MapBoard = "Scripts/map_board.gd"',
            ),
            encoding="utf-8",
        )
        rule = DependencyBoundaryRule(self.root, self.config)
        path = self.write("game/battle/a.gd", "")
        findings = rule.check(path, "", self.root)
        self.assertEqual(len(findings), 1)
        self.assertIn("MapBoard", findings[0].message)


if __name__ == "__main__":
    unittest.main()
