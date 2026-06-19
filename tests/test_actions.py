import tempfile
import unittest
from pathlib import Path

from mac_clean.actions import ActionContext, clean_directory_contents, run_deep_clean_actions
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


if __name__ == "__main__":
    unittest.main()
