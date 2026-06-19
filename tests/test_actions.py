import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from mac_clean.actions import ActionContext, clean_directory_contents, run_deep_clean_actions, run_fresh_start_actions
from mac_clean.models import Finding, RiskLevel


class ActionTests(unittest.TestCase):
    def test_dry_run_does_not_delete_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "cache"
            target.mkdir()
            file_path = target / "file.txt"
            file_path.write_text("data")

            result = clean_directory_contents(target, ActionContext(dry_run=True, yes_safe=True))

            self.assertTrue(file_path.exists())
            self.assertTrue(result.dry_run)
            self.assertGreaterEqual(result.bytes_reclaimed, 0)

    def test_clean_directory_contents_deletes_children_not_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "cache"
            nested = target / "nested"
            nested.mkdir(parents=True)
            (nested / "file.txt").write_text("data")

            result = clean_directory_contents(target, ActionContext(dry_run=False, yes_safe=True))

            self.assertTrue(target.exists())
            self.assertEqual(list(target.iterdir()), [])
            self.assertFalse(result.dry_run)

    def test_refuses_protected_paths(self):
        for protected in (Path("/"), Path("/System"), Path.home()):
            with self.assertRaises(ValueError):
                clean_directory_contents(protected, ActionContext(dry_run=True, yes_safe=True))

    def test_deep_clean_removes_actionable_moderate_findings(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache_file = Path(tmp) / "home" / ".cache" / "pip" / "http" / "cache.bin"
            cache_file.parent.mkdir(parents=True)
            cache_file.write_text("data")
            finding = Finding(
                category="Developer",
                title="pip cache",
                path=str(cache_file.parent.parent),
                bytes_reclaimable=4,
                risk=RiskLevel.MODERATE,
                action="clean-directory-contents",
                detail="Package manager cache.",
            )

            results = run_deep_clean_actions([finding], ActionContext(deep_clean=True))

            self.assertEqual(len(results), 1)
            self.assertFalse(cache_file.exists())

    def test_fresh_start_removes_allowlisted_moderate_and_skips_deep_only_moderate(self):
        with tempfile.TemporaryDirectory() as tmp:
            npm_file = Path(tmp) / "home" / ".npm" / "_cacache" / "content.bin"
            cursor_file = Path(tmp) / "home" / "Library" / "Application Support" / "Cursor" / "GPUCache" / "gpu.bin"
            for file_path in (npm_file, cursor_file):
                file_path.parent.mkdir(parents=True, exist_ok=True)
                file_path.write_text("data")
            findings = [
                Finding(
                    category="Developer",
                    title="npm cache",
                    path=str(npm_file.parent),
                    bytes_reclaimable=4,
                    risk=RiskLevel.MODERATE,
                    action="clean-directory-contents",
                    detail="Package manager cache.",
                ),
                Finding(
                    category="AI and Editors",
                    title="Cursor GPUCache",
                    path=str(cursor_file.parent),
                    bytes_reclaimable=4,
                    risk=RiskLevel.MODERATE,
                    action="clean-directory-contents",
                    detail="Editor cache.",
                ),
            ]

            results = run_fresh_start_actions(findings, ActionContext(fresh_start=True))

            self.assertEqual(len(results), 1)
            self.assertFalse(npm_file.exists())
            self.assertTrue(cursor_file.exists())

    def test_fresh_start_skips_allowlisted_title_with_unexpected_action(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache_file = Path(tmp) / "home" / "Library" / "Caches" / "Homebrew" / "download.tar.gz"
            cache_file.parent.mkdir(parents=True)
            cache_file.write_text("data")
            finding = Finding(
                category="Developer",
                title="Homebrew cache",
                path=str(cache_file.parent),
                bytes_reclaimable=4,
                risk=RiskLevel.MODERATE,
                action="remove-path",
                detail="Unexpected action for this fresh-start allowlisted title.",
            )

            results = run_fresh_start_actions([finding], ActionContext(fresh_start=True))

            self.assertEqual(results, [])
            self.assertTrue(cache_file.exists())

    def test_deep_clean_skips_high_risk_even_when_action_is_set(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            backup_file = (
                root
                / "home"
                / "Library"
                / "Application Support"
                / "MobileSync"
                / "Backup"
                / "device"
                / "backup.bin"
            )
            backup_file.parent.mkdir(parents=True)
            backup_file.write_text("data")
            finding = Finding(
                category="Backups",
                title="iOS device backups",
                path=str(backup_file.parent.parent),
                bytes_reclaimable=4,
                risk=RiskLevel.HIGH,
                action="remove-path",
                detail="High-risk local device backup.",
            )

            results = run_deep_clean_actions([finding], ActionContext(deep_clean=True))

            self.assertEqual(results, [])
            self.assertTrue(backup_file.exists())

    def test_missing_path_is_reported_as_already_absent(self):
        with tempfile.TemporaryDirectory() as tmp:
            missing = Path(tmp) / "gone"
            finding = Finding(
                category="Caches",
                title="missing cache",
                path=str(missing),
                bytes_reclaimable=10,
                risk=RiskLevel.MODERATE,
                action="clean-directory-contents",
                detail="Already cleaned by parent action.",
            )

            results = run_deep_clean_actions([finding], ActionContext(deep_clean=True, dry_run=True))

            self.assertEqual(len(results), 1)
            self.assertEqual(results[0].bytes_reclaimed, 0)
            self.assertIn("already absent", results[0].message)

    def test_deep_clean_removes_known_electron_cache_subdirectories(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "app"
            cache = root / "Cache"
            code_cache = root / "Code Cache"
            preserved = root / "IndexedDB"
            cache.mkdir(parents=True)
            code_cache.mkdir()
            preserved.mkdir()
            (cache / "cache.bin").write_text("data")
            (code_cache / "code.bin").write_text("data")
            (preserved / "state.bin").write_text("data")
            finding = Finding(
                category="Browsers",
                title="Electron cache",
                path=str(root),
                bytes_reclaimable=8,
                risk=RiskLevel.MODERATE,
                action="clean-electron-cache-subdirs",
                detail="Known Electron cache subdirectories.",
            )

            results = run_deep_clean_actions([finding], ActionContext(deep_clean=True))

            self.assertEqual(len(results), 1)
            self.assertFalse(cache.exists())
            self.assertFalse(code_cache.exists())
            self.assertTrue(preserved.exists())

    def test_command_backed_action_dry_run_does_not_execute(self):
        finding = Finding(
            category="Developer",
            title="Unavailable simulators",
            path="xcrun simctl delete unavailable",
            bytes_reclaimable=0,
            risk=RiskLevel.MODERATE,
            action="run-xcrun-simctl-delete-unavailable",
            detail="Deletes unavailable simulator records.",
        )

        with patch("mac_clean.actions.subprocess.run") as run:
            results = run_deep_clean_actions([finding], ActionContext(deep_clean=True, dry_run=True))

        run.assert_not_called()
        self.assertEqual(len(results), 1)
        self.assertTrue(results[0].dry_run)
        self.assertIn("Would run", results[0].message)

    def test_command_backed_action_runs_absolute_argv(self):
        finding = Finding(
            category="Developer",
            title="Unavailable simulators",
            path="/usr/bin/xcrun simctl delete unavailable",
            bytes_reclaimable=0,
            risk=RiskLevel.MODERATE,
            action="run-xcrun-simctl-delete-unavailable",
            detail="Deletes unavailable simulator records.",
        )

        with patch("mac_clean.actions.subprocess.run") as run:
            run.return_value.returncode = 0
            run.return_value.stderr = ""
            results = run_deep_clean_actions([finding], ActionContext(deep_clean=True))

        run.assert_called_once_with(
            ("/usr/bin/xcrun", "simctl", "delete", "unavailable"),
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(len(results), 1)
        self.assertFalse(results[0].dry_run)
        self.assertEqual(results[0].message, "Command completed.")

    def test_command_backed_action_reports_launch_failure(self):
        finding = Finding(
            category="Developer",
            title="Unavailable simulators",
            path="/usr/bin/xcrun simctl delete unavailable",
            bytes_reclaimable=0,
            risk=RiskLevel.MODERATE,
            action="run-xcrun-simctl-delete-unavailable",
            detail="Deletes unavailable simulator records.",
        )

        with patch("mac_clean.actions.subprocess.run") as run:
            run.side_effect = FileNotFoundError("missing xcrun")
            results = run_deep_clean_actions([finding], ActionContext(deep_clean=True))

        self.assertEqual(len(results), 1)
        self.assertFalse(results[0].dry_run)
        self.assertIn("could not be run", results[0].message)
        self.assertIn("missing xcrun", results[0].message)

    def test_unknown_command_action_is_ignored(self):
        finding = Finding(
            category="Developer",
            title="Unknown command",
            path="unknown",
            bytes_reclaimable=0,
            risk=RiskLevel.MODERATE,
            action="run-rm-rf-home",
            detail="Invalid action.",
        )

        results = run_deep_clean_actions([finding], ActionContext(deep_clean=True, dry_run=True))

        self.assertEqual(results, [])


if __name__ == "__main__":
    unittest.main()
