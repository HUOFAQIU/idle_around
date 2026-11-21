import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "tools" / "git_guard.py"


def run_guard(command):
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})
    result = subprocess.run(
        [sys.executable, "-X", "utf8", "-I", str(SCRIPT)],
        input=payload,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return result.returncode


class DangerousCommandsTest(unittest.TestCase):
    def test_force_push(self):
        self.assertEqual(run_guard("git push --force origin main"), 2)

    def test_force_with_lease_push(self):
        self.assertEqual(run_guard("git push --force-with-lease origin main"), 2)

    def test_short_force_push(self):
        self.assertEqual(run_guard("git push -f origin main"), 2)

    def test_refspec_force_push(self):
        self.assertEqual(run_guard("git push origin +main"), 2)

    def test_combined_force_push(self):
        self.assertEqual(run_guard("git push -fu origin main"), 2)

    def test_reset_hard(self):
        self.assertEqual(run_guard("git reset --hard HEAD~1"), 2)

    def test_reset_with_intervening_args(self):
        self.assertEqual(run_guard("git reset HEAD --hard"), 2)

    def test_clean_force(self):
        self.assertEqual(run_guard("git clean -fd"), 2)

    def test_branch_force_delete(self):
        self.assertEqual(run_guard("git branch -D feature"), 2)

    def test_branch_long_force_delete(self):
        self.assertEqual(run_guard("git branch --delete --force feature"), 2)

    def test_checkout_discard(self):
        self.assertEqual(run_guard("git checkout -- src/main.gd"), 2)

    def test_checkout_ref_path(self):
        self.assertEqual(run_guard("git checkout HEAD -- src/main.gd"), 2)

    def test_checkout_dot(self):
        self.assertEqual(run_guard("git checkout ."), 2)

    def test_restore_worktree(self):
        self.assertEqual(run_guard("git restore ."), 2)

    def test_restore_staged_and_worktree(self):
        self.assertEqual(run_guard("git restore --staged --worktree file.gd"), 2)

    def test_compound_command(self):
        self.assertEqual(run_guard("git status && git reset --hard"), 2)


class SafeCommandsTest(unittest.TestCase):
    def test_plain_push(self):
        self.assertEqual(run_guard("git push origin main"), 0)

    def test_status(self):
        self.assertEqual(run_guard("git status --short"), 0)

    def test_clean_dry_run(self):
        self.assertEqual(run_guard("git clean -n"), 0)

    def test_soft_branch_delete(self):
        self.assertEqual(run_guard("git branch -d feature"), 0)

    def test_checkout_branch(self):
        self.assertEqual(run_guard("git checkout main"), 0)

    def test_checkout_detach(self):
        self.assertEqual(run_guard("git checkout --detach"), 0)

    def test_branch_soft_long_delete(self):
        self.assertEqual(run_guard("git branch --delete feature"), 0)

    def test_restore_staged(self):
        self.assertEqual(run_guard("git restore --staged file.gd"), 0)

    def test_unrelated_command(self):
        self.assertEqual(run_guard("bash tools/check.sh --all"), 0)

    def test_branch_name_containing_force(self):
        self.assertEqual(run_guard("git push origin feature--force"), 0)


class MalformedInputTest(unittest.TestCase):
    def test_malformed_json_passes(self):
        result = subprocess.run(
            [sys.executable, "-X", "utf8", "-I", str(SCRIPT)],
            input="not json",
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        self.assertEqual(result.returncode, 0)

    def test_non_object_json_passes(self):
        result = subprocess.run(
            [sys.executable, "-X", "utf8", "-I", str(SCRIPT)],
            input="[]",
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        self.assertEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
