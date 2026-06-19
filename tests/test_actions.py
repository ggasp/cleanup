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

    def test_deep_clean_runs_with_deep_clean_context_without_fresh_start(self):
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


if __name__ == "__main__":
    unittest.main()
