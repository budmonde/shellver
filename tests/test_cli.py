from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).parents[1]


class ShellverCliTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.state_home = Path(self.temporary_directory.name)
        self.shellver_directory = self.state_home / "shellver"
        self.shellver_directory.mkdir()
        self.write_component("common", "1")
        self.write_component("local", "4")
        self.write_component("machine", "machine-a")

    def write_component(self, name: str, value: str) -> None:
        (self.shellver_directory / name).write_text(f"{value}\n", encoding="utf-8")

    def run_shellver(self, *arguments: str, loaded: str | None = None) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment["PYTHONPATH"] = str(PROJECT_ROOT / "src")
        environment["XDG_STATE_HOME"] = str(self.state_home)
        if loaded is None:
            environment.pop("SHELLVER", None)
        else:
            environment["SHELLVER"] = loaded
        return subprocess.run(
            [sys.executable, "-m", "shellver", *arguments],
            check=False,
            capture_output=True,
            encoding="utf-8",
            env=environment,
        )

    def test_current_prints_composite_generation(self) -> None:
        result = self.run_shellver("current")

        self.assertEqual(0, result.returncode)
        self.assertEqual("common:1|local:4|machine:machine-a", result.stdout.strip())

    def test_status_distinguishes_current_and_stale_shells(self) -> None:
        generation = "common:1|local:4|machine:machine-a"

        current = self.run_shellver(loaded=generation)
        stale = self.run_shellver(loaded="common:0|local:4|machine:machine-a")

        self.assertEqual(0, current.returncode)
        self.assertIn("status:  current", current.stdout)
        self.assertEqual(1, stale.returncode)
        self.assertIn("status:  stale", stale.stdout)

    def test_bump_machine_replaces_machine_generation(self) -> None:
        before = (self.shellver_directory / "machine").read_text(encoding="utf-8")

        result = self.run_shellver("bump-machine")

        after = (self.shellver_directory / "machine").read_text(encoding="utf-8")
        self.assertEqual(0, result.returncode)
        self.assertNotEqual(before, after)
        self.assertEqual(result.stdout.strip(), after.strip())
        self.assertFalse((self.shellver_directory / "machine").is_symlink())

    def test_bump_machine_refuses_linked_machine_generation(self) -> None:
        machine = self.shellver_directory / "machine"
        target = self.state_home / "linked-machine"
        target.write_text("linked\n", encoding="utf-8")
        machine.unlink()
        try:
            machine.symlink_to(target)
        except OSError as error:
            self.skipTest(f"file symlinks are unavailable: {error}")

        result = self.run_shellver("bump-machine")

        self.assertEqual(1, result.returncode)
        self.assertIn("refusing to replace linked machine generation", result.stderr)
        self.assertEqual("linked", target.read_text(encoding="utf-8").strip())
        self.assertTrue(machine.is_symlink())

    def test_missing_component_uses_placeholder(self) -> None:
        (self.shellver_directory / "local").unlink()

        result = self.run_shellver("current")

        self.assertEqual("common:1|local:-|machine:machine-a", result.stdout.strip())

    def test_init_emits_self_contained_shell_integrations(self) -> None:
        capabilities = {
            "bash": "shellver_is_stale",
            "zsh": "shellver_is_stale",
            "powershell": "Test-ShellverStale",
        }
        for shell, capability in capabilities.items():
            with self.subTest(shell=shell):
                result = self.run_shellver("init", shell)
                self.assertEqual(0, result.returncode)
                self.assertIn("SHELLVER", result.stdout)
                self.assertIn(capability, result.stdout)
                self.assertNotIn("[shellver stale]", result.stdout)
                self.assertNotIn("PROMPT_COMMAND", result.stdout)
                self.assertNotIn("add-zsh-hook", result.stdout)
                self.assertNotIn("function global:prompt", result.stdout)
                self.assertNotIn(str(PROJECT_ROOT), result.stdout)
                self.assertNotIn("python", result.stdout.lower())
                self.assertNotIn("git ", result.stdout.lower())


if __name__ == "__main__":
    unittest.main()
