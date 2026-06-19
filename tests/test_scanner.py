import tempfile
import unittest
from pathlib import Path

from mac_clean.models import RiskLevel
from mac_clean.scanner import ScanConfig, scan


def write_file(path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"x" * size)


class ScannerTests(unittest.TestCase):
    def test_scan_reports_common_storage_opportunities(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            write_file(home / ".Trash" / "old.bin", 100)
            write_file(home / "Downloads" / "installer.dmg", 200)
            write_file(home / "Library" / "Caches" / "app" / "cache.bin", 300)
            write_file(home / "Movies" / "large.mov", 700)

            report = scan(ScanConfig(home=home, system_root=root, large_file_threshold=500, min_size=1))

            titles = {finding.title for finding in report.findings}
            self.assertIn("Trash", titles)
            self.assertIn("Downloads installers", titles)
            self.assertIn("User caches", titles)
            self.assertIn("Large files", titles)

    def test_scan_reports_deep_reclaim_opportunities(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            write_file(home / "Library" / "Application Support" / "Google" / "Chrome" / "Default" / "Code Cache" / "code.bin", 100)
            write_file(home / ".npm" / "_cacache" / "content.bin", 200)
            write_file(home / "Library" / "Developer" / "CoreSimulator" / "Caches" / "sim.bin", 300)
            write_file(home / "Library" / "Containers" / "com.apple.mail" / "Data" / "Library" / "Mail Downloads" / "attachment.pdf", 400)
            write_file(home / "Workspace" / "app" / "node_modules" / "package" / "index.js", 500)
            write_file(root / "Library" / "Application Support" / "com.apple.idleassetsd" / "Customer" / "4KSDR240FPS" / "video.mov", 600)

            report = scan(ScanConfig(home=home, system_root=root, min_size=1))

            by_title = {finding.title: finding for finding in report.findings}
            self.assertEqual(by_title["Chrome Code Cache"].action, "clean-directory-contents")
            self.assertEqual(by_title["npm cache"].action, "clean-directory-contents")
            self.assertEqual(by_title["CoreSimulator caches"].action, "clean-directory-contents")
            self.assertEqual(by_title["Mail downloads"].action, "clean-directory-contents")
            self.assertEqual(by_title["Project dependencies"].action, "remove-path")
            self.assertEqual(by_title["Aerial and wallpaper videos"].action, "clean-directory-contents")

    def test_scan_respects_min_size(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            write_file(home / ".Trash" / "small.bin", 10)

            report = scan(ScanConfig(home=home, system_root=root, min_size=50))

            self.assertEqual(report.findings, [])

    def test_scan_marks_ios_backups_high_risk(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            write_file(home / "Library" / "Application Support" / "MobileSync" / "Backup" / "device" / "backup.bin", 100)

            report = scan(ScanConfig(home=home, system_root=root, min_size=1))
            backup = next(f for f in report.findings if f.title == "iOS device backups")

            self.assertEqual(backup.risk, RiskLevel.HIGH)
            self.assertIsNone(backup.action)


if __name__ == "__main__":
    unittest.main()
