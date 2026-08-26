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
        temporary_root = Path(self.temporary_directory.name)
        self.config_home = temporary_root / "config"
        self.state_home = temporary_root / "state"
        self.config_directory = self.config_home / "shellver"
        self.state_directory = self.state_home / "shellver"
        self.config_directory.mkdir(parents=True)
        self.state_directory.mkdir(parents=True)
        self.write_config_generation("common", "1")
        self.write_config_generation("local", "4")
        self.write_machine_generation("7")

    def write_config_generation(self, name: str, value: str) -> None:
        (self.config_directory / name).write_text(f"{value}\n", encoding="utf-8")

    def write_machine_generation(self, value: str) -> None:
        (self.state_directory / "machine").write_text(f"{value}\n", encoding="utf-8")

    def run_shellver(self, *arguments: str, loaded: str | None = None) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment["PYTHONPATH"] = str(PROJECT_ROOT / "src")
        environment["XDG_CONFIG_HOME"] = str(self.config_home)
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
        self.assertEqual("common:1|local:4|machine:7", result.stdout.strip())

    def test_current_discovers_arbitrary_config_generations_in_name_order(self) -> None:
        self.write_config_generation("zeta", "9")
        self.write_config_generation("alpha", "2")

        result = self.run_shellver("current")

        self.assertEqual(0, result.returncode)
        self.assertEqual(
            "alpha:2|common:1|local:4|zeta:9|machine:7",
            result.stdout.strip(),
        )

    def test_status_distinguishes_current_and_stale_shells(self) -> None:
        generation = "common:1|local:4|machine:7"

        current = self.run_shellver(loaded=generation)
        stale = self.run_shellver(loaded="common:0|local:4|machine:7")

        self.assertEqual(0, current.returncode)
        self.assertIn("status:  current", current.stdout)
        self.assertEqual(1, stale.returncode)
        self.assertIn("status:  stale", stale.stdout)

    def test_status_compares_one_generation(self) -> None:
        generation = "common:1|local:4|machine:7"

        current = self.run_shellver("status", "common", loaded=generation)
        stale = self.run_shellver(
            "status", "machine", loaded="common:1|local:4|machine:0"
        )

        self.assertEqual(0, current.returncode)
        self.assertIn("generation: common", current.stdout)
        self.assertIn("loaded:  1", current.stdout)
        self.assertIn("current: 1", current.stdout)
        self.assertIn("status:  current", current.stdout)
        self.assertEqual(1, stale.returncode)
        self.assertIn("generation: machine", stale.stdout)
        self.assertIn("loaded:  0", stale.stdout)
        self.assertIn("current: 7", stale.stdout)
        self.assertIn("status:  stale", stale.stdout)

    def test_status_rejects_unknown_generation(self) -> None:
        result = self.run_shellver("status", "missing")

        self.assertEqual(2, result.returncode)
        self.assertIn("generation does not exist: missing", result.stderr)

    def test_bump_machine_increments_state_generation(self) -> None:
        machine = self.state_directory / "machine"

        result = self.run_shellver("bump", "machine")

        self.assertEqual(0, result.returncode)
        self.assertEqual("8", result.stdout.strip())
        self.assertEqual("8", machine.read_text(encoding="utf-8").strip())
        self.assertFalse(machine.is_symlink())

    def test_bump_machine_migrates_legacy_opaque_generation(self) -> None:
        machine = self.state_directory / "machine"
        self.write_machine_generation("legacy-opaque-token")

        result = self.run_shellver("bump", "machine")

        self.assertEqual(0, result.returncode)
        self.assertEqual("1", result.stdout.strip())
        self.assertEqual("1", machine.read_text(encoding="utf-8").strip())

    def test_bump_machine_refuses_linked_machine_generation(self) -> None:
        machine = self.state_directory / "machine"
        target = self.state_home / "linked-machine"
        target.write_text("7\n", encoding="utf-8")
        machine.unlink()
        try:
            machine.symlink_to(target)
        except OSError as error:
            self.skipTest(f"file symlinks are unavailable: {error}")

        result = self.run_shellver("bump", "machine")

        self.assertEqual(1, result.returncode)
        self.assertIn("refusing to replace linked machine generation", result.stderr)
        self.assertEqual("7", target.read_text(encoding="utf-8").strip())
        self.assertTrue(machine.is_symlink())

    def test_bump_config_generation_updates_link_target(self) -> None:
        target = Path(self.temporary_directory.name) / "repository-generation"
        target.write_text("11\n", encoding="utf-8")
        generation = self.config_directory / "repository"
        try:
            generation.symlink_to(target)
        except OSError as error:
            self.skipTest(f"file symlinks are unavailable: {error}")

        result = self.run_shellver("bump", "repository")

        self.assertEqual(0, result.returncode)
        self.assertEqual("12", result.stdout.strip())
        self.assertEqual("12", target.read_text(encoding="utf-8").strip())
        self.assertTrue(generation.is_symlink())

    def test_bump_rejects_missing_or_non_numeric_config_generation(self) -> None:
        self.write_config_generation("invalid", "not-a-number")

        missing = self.run_shellver("bump", "missing")
        invalid = self.run_shellver("bump", "invalid")

        self.assertEqual(2, missing.returncode)
        self.assertIn("generation does not exist", missing.stderr)
        self.assertEqual(2, invalid.returncode)
        self.assertIn("generation must contain a non-negative integer", invalid.stderr)

    def test_reserved_machine_config_generation_is_a_misconfiguration(self) -> None:
        self.write_config_generation("machine", "99")

        current = self.run_shellver("current")
        bump = self.run_shellver("bump", "machine")

        self.assertEqual(2, current.returncode)
        self.assertIn("reserved generation name 'machine'", current.stderr)
        self.assertEqual(2, bump.returncode)
        self.assertIn("reserved generation name 'machine'", bump.stderr)

    def test_missing_config_generation_is_not_part_of_composite(self) -> None:
        (self.config_directory / "local").unlink()

        result = self.run_shellver("current")

        self.assertEqual("common:1|machine:7", result.stdout.strip())

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
                self.assertIn("XDG_CONFIG_HOME", result.stdout)
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
