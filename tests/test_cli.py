import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from mac_clean.actions import ActionResult
from mac_clean.cli import main


class CliTests(unittest.TestCase):
    def test_scan_json_outputs_valid_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            trash = home / ".Trash"
            trash.mkdir(parents=True)
            (trash / "file.txt").write_text("data")
            stdout = io.StringIO()

            with contextlib.redirect_stdout(stdout):
                exit_code = main(["scan", "--json", "--home", str(home), "--system-root", tmp, "--min-size", "1B"])

            self.assertEqual(exit_code, 0)
            payload = json.loads(stdout.getvalue())
            self.assertEqual(payload["findings"][0]["title"], "Trash")

    def test_clean_dry_run_yes_safe_does_not_delete(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            cache = home / "Library" / "Caches" / "app"
            cache.mkdir(parents=True)
            file_path = cache / "file.txt"
            file_path.write_text("data")
            stdout = io.StringIO()

            with contextlib.redirect_stdout(stdout):
                exit_code = main([
                    "clean",
                    "--dry-run",
                    "--yes-safe",
                    "--home",
                    str(home),
                    "--system-root",
                    tmp,
                    "--min-size",
                    "1B",
                ])

            self.assertEqual(exit_code, 0)
            self.assertTrue(file_path.exists())

    def test_clean_yes_safe_cleans_actionable_safe_findings_beyond_basic_cache_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            diagnostic_report = home / "Library" / "Logs" / "DiagnosticReports" / "crash.crash"
            diagnostic_report.parent.mkdir(parents=True)
            diagnostic_report.write_text("data")
            stdout = io.StringIO()

            with contextlib.redirect_stdout(stdout):
                exit_code = main([
                    "clean",
                    "--yes-safe",
                    "--home",
                    str(home),
                    "--system-root",
                    str(root),
                    "--min-size",
                    "1B",
                ])

            self.assertEqual(exit_code, 0)
            self.assertFalse(diagnostic_report.exists())

    def test_fresh_start_requires_keyword(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            cache = home / "Library" / "Caches" / "app"
            cache.mkdir(parents=True)
            file_path = cache / "file.txt"
            file_path.write_text("data")
            stdout = io.StringIO()

            with contextlib.redirect_stdout(stdout):
                exit_code = main(["fresh-start", "--home", str(home), "--system-root", tmp, "--min-size", "1B"])

            self.assertEqual(exit_code, 2)
            self.assertTrue(file_path.exists())

    def test_deep_clean_requires_keyword(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            cache = home / "Library" / "Caches" / "app" / "cache.bin"
            cache.parent.mkdir(parents=True)
            cache.write_text("data")
            stdout = io.StringIO()

            with contextlib.redirect_stdout(stdout):
                exit_code = main(["deep-clean", "--home", str(home), "--system-root", str(root), "--min-size", "1B"])

            self.assertEqual(exit_code, 2)
            self.assertTrue(cache.exists())
            self.assertIn("No cleanup performed", stdout.getvalue())

    def test_deep_clean_dry_run_does_not_delete_actionable_moderate_findings(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            cache = home / ".cache" / "pip" / "http" / "cache.bin"
            cache.parent.mkdir(parents=True)
            cache.write_text("data")
            stdout = io.StringIO()

            with contextlib.redirect_stdout(stdout):
                exit_code = main([
                    "deep-clean",
                    "--dry-run",
                    "--i-understand",
                    "deep-clean",
                    "--home",
                    str(home),
                    "--system-root",
                    str(root),
                    "--min-size",
                    "1B",
                ])

            self.assertEqual(exit_code, 0)
            self.assertTrue(cache.exists())
            self.assertIn("Would reclaim", stdout.getvalue())

    def test_deep_clean_cleans_aggressive_moderate_findings_but_preserves_report_only_data(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            safari_file = home / "Library" / "Safari" / "WebsiteData" / "site.bin"
            ai_cache = home / "Library" / "Application Support" / "Cursor" / "GPUCache" / "gpu.bin"
            ios_backup = home / "Library" / "Application Support" / "MobileSync" / "Backup" / "device" / "backup.bin"
            large_file = home / "Movies" / "large.mov"
            for path in (safari_file, ai_cache, ios_backup, large_file):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("data")
            large_file.write_bytes(b"x" * 2048)
            stdout = io.StringIO()

            with contextlib.redirect_stdout(stdout):
                exit_code = main([
                    "deep-clean",
                    "--i-understand",
                    "deep-clean",
                    "--home",
                    str(home),
                    "--system-root",
                    str(root),
                    "--min-size",
                    "1B",
                    "--large-file-threshold",
                    "1K",
                ])

            self.assertEqual(exit_code, 0)
            self.assertFalse(safari_file.exists())
            self.assertFalse(ai_cache.exists())
            self.assertTrue(ios_backup.exists())
            self.assertTrue(large_file.exists())

    def test_fresh_start_preserves_deep_only_moderate_findings(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            safari_file = home / "Library" / "Safari" / "WebsiteData" / "site.bin"
            cursor_cache = home / "Library" / "Application Support" / "Cursor" / "GPUCache" / "gpu.bin"
            npm_cache = home / ".npm" / "_cacache" / "content.bin"
            for path in (safari_file, cursor_cache, npm_cache):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("data")
            stdout = io.StringIO()

            with contextlib.redirect_stdout(stdout):
                exit_code = main([
                    "fresh-start",
                    "--i-understand",
                    "fresh-start",
                    "--home",
                    str(home),
                    "--system-root",
                    str(root),
                    "--min-size",
                    "1B",
                ])

            self.assertEqual(exit_code, 0)
            self.assertTrue(safari_file.exists())
            self.assertTrue(cursor_cache.exists())
            self.assertFalse(npm_cache.exists())

    def test_fresh_start_cleans_actionable_safe_and_moderate_findings_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            safe_cache = home / "Library" / "Caches" / "app" / "cache.bin"
            moderate_cache = home / ".npm" / "_cacache" / "content.bin"
            installer = home / "Downloads" / "installer.dmg"
            project_dependency = home / "Workspace" / "app" / "node_modules" / "pkg" / "index.js"
            high_risk_backup = home / "Library" / "Application Support" / "MobileSync" / "Backup" / "device" / "backup.bin"
            for path in (safe_cache, moderate_cache, installer, project_dependency, high_risk_backup):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("data")
            stdout = io.StringIO()

            with contextlib.redirect_stdout(stdout):
                exit_code = main([
                    "fresh-start",
                    "--i-understand",
                    "fresh-start",
                    "--home",
                    str(home),
                    "--system-root",
                    str(root),
                    "--min-size",
                    "1B",
                ])

            self.assertEqual(exit_code, 0)
            self.assertFalse(safe_cache.exists())
            self.assertFalse(moderate_cache.exists())
            self.assertFalse(installer.exists())
            self.assertFalse((home / "Workspace" / "app" / "node_modules").exists())
            self.assertTrue(high_risk_backup.exists())

    def test_fresh_start_tolerates_nested_findings_removed_by_parent_action(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            homebrew_cache = home / "Library" / "Caches" / "Homebrew" / "download.tar.gz"
            homebrew_cache.parent.mkdir(parents=True)
            homebrew_cache.write_text("data")
            stdout = io.StringIO()

            with contextlib.redirect_stdout(stdout):
                exit_code = main([
                    "fresh-start",
                    "--i-understand",
                    "fresh-start",
                    "--home",
                    str(home),
                    "--system-root",
                    str(root),
                    "--min-size",
                    "1B",
                ])

            self.assertEqual(exit_code, 0)
            self.assertFalse(homebrew_cache.exists())

    def test_doctor_returns_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            stdout = io.StringIO()

            with contextlib.redirect_stdout(stdout):
                exit_code = main(["doctor", "--home", str(home), "--system-root", tmp])

            self.assertEqual(exit_code, 0)

    def test_clean_outputs_action_message(self):
        output = self._run_cleanup_with_result_message(
            ["clean", "--yes-safe"],
            "mac_clean.cli.run_safe_actions",
        )

        self.assertIn("Reclaimed 0 B from /tmp/action-target - Command exited with 1.", output)

    def test_fresh_start_outputs_action_message(self):
        output = self._run_cleanup_with_result_message(
            ["fresh-start", "--i-understand", "fresh-start"],
            "mac_clean.cli.run_fresh_start_actions",
        )

        self.assertIn("Reclaimed 0 B from /tmp/action-target - Command exited with 1.", output)

    def test_deep_clean_outputs_action_message(self):
        output = self._run_cleanup_with_result_message(
            ["deep-clean", "--i-understand", "deep-clean"],
            "mac_clean.cli.run_deep_clean_actions",
        )

        self.assertIn("Reclaimed 0 B from /tmp/action-target - Command exited with 1.", output)

    def _run_cleanup_with_result_message(self, command: list[str], action_runner: str) -> str:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "home"
            home.mkdir()
            stdout = io.StringIO()
            result = ActionResult(
                action="run-test-command",
                path="/tmp/action-target",
                bytes_reclaimed=0,
                dry_run=False,
                message="Command exited with 1.",
            )

            with patch(action_runner, return_value=[result]):
                with contextlib.redirect_stdout(stdout):
                    exit_code = main([*command, "--home", str(home), "--system-root", tmp])

            self.assertEqual(exit_code, 0)
            return stdout.getvalue()


if __name__ == "__main__":
    unittest.main()
