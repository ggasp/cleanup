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

    def test_scan_reports_developer_professional_and_ai_caches(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            write_file(home / ".conda" / "pkgs" / "pkg.tar.bz2", 100)
            write_file(home / ".gem" / "cache" / "gem.gem", 100)
            write_file(home / "Library" / "Caches" / "uv" / "wheel.whl", 100)
            write_file(home / "Library" / "Caches" / "go-build" / "obj", 100)
            write_file(home / "go" / "pkg" / "mod" / "cache" / "download" / "mod.zip", 100)
            write_file(home / "Library" / "Developer" / "Xcode" / "watchOS DeviceSupport" / "symbols.bin", 100)
            write_file(home / "Library" / "Application Support" / "Adobe" / "Common" / "Media Cache Files" / "media.cfa", 100)
            write_file(home / "Library" / "Application Support" / "Claude" / "Cache" / "cache.bin", 100)
            write_file(home / "Library" / "Application Support" / "Cursor" / "Code Cache" / "code.bin", 100)

            report = scan(ScanConfig(home=home, system_root=root, min_size=1))
            by_title = {finding.title: finding for finding in report.findings}

            self.assertEqual(by_title["conda packages"].action, "clean-directory-contents")
            self.assertEqual(by_title["Ruby gem cache"].action, "clean-directory-contents")
            self.assertEqual(by_title["uv cache"].action, "clean-directory-contents")
            self.assertEqual(by_title["Go build cache"].action, "clean-directory-contents")
            self.assertEqual(by_title["Go module download cache"].action, "clean-directory-contents")
            self.assertEqual(by_title["Xcode watchOS DeviceSupport"].action, "clean-directory-contents")
            self.assertEqual(by_title["Adobe media cache files"].action, "clean-directory-contents")
            self.assertEqual(by_title["Claude Cache"].action, "clean-directory-contents")
            self.assertEqual(by_title["Cursor Code Cache"].action, "clean-directory-contents")

    def test_scan_reports_unavailable_simulators_command(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"

            report = scan(ScanConfig(home=home, system_root=root, min_size=0))
            by_title = {finding.title: finding for finding in report.findings}

            self.assertEqual(by_title["Unavailable simulators"].action, "run-xcrun-simctl-delete-unavailable")
            self.assertEqual(by_title["Unavailable simulators"].bytes_reclaimable, 0)

    def test_scan_reports_browser_safari_and_generated_caches(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            write_file(home / "Library" / "Safari" / "Databases" / "site.db", 100)
            write_file(home / "Library" / "Safari" / "LocalStorage" / "site.localstorage", 100)
            write_file(home / "Library" / "Safari" / "WebsiteData" / "data.bin", 100)
            write_file(home / "Library" / "Application Support" / "Google" / "Chrome" / "Default" / "GPUCache" / "gpu.bin", 100)
            write_file(home / "Library" / "Application Support" / "Google" / "Chrome" / "Default" / "Service Worker" / "CacheStorage" / "cache.bin", 100)
            write_file(home / "Library" / "Application Support" / "com.operasoftware.Opera" / "Default" / "Code Cache" / "code.bin", 100)
            write_file(home / "Library" / "Logs" / "DiagnosticReports" / "crash.crash", 100)
            write_file(home / "Library" / "Logs" / "CrashReporter" / "crash.log", 100)
            write_file(home / "Library" / "Caches" / "com.apple.appstore" / "download.bin", 100)
            write_file(root / "Library" / "Caches" / "com.apple.SoftwareUpdate" / "update.bin", 100)

            report = scan(ScanConfig(home=home, system_root=root, min_size=1))
            by_title = {finding.title: finding for finding in report.findings}

            self.assertEqual(by_title["Safari Databases"].action, "clean-directory-contents")
            self.assertEqual(by_title["Safari Databases"].risk, RiskLevel.MODERATE)
            self.assertEqual(by_title["Safari LocalStorage"].action, "clean-directory-contents")
            self.assertEqual(by_title["Safari LocalStorage"].risk, RiskLevel.MODERATE)
            self.assertEqual(by_title["Safari WebsiteData"].action, "clean-directory-contents")
            self.assertEqual(by_title["Safari WebsiteData"].risk, RiskLevel.MODERATE)
            self.assertEqual(by_title["Chrome GPUCache"].action, "clean-directory-contents")
            self.assertEqual(by_title["Chrome GPUCache"].risk, RiskLevel.MODERATE)
            self.assertEqual(by_title["Chrome Service Worker CacheStorage"].action, "clean-directory-contents")
            self.assertEqual(by_title["Chrome Service Worker CacheStorage"].risk, RiskLevel.MODERATE)
            self.assertEqual(by_title["Opera Code Cache"].action, "clean-directory-contents")
            self.assertEqual(by_title["Opera Code Cache"].risk, RiskLevel.MODERATE)
            self.assertEqual(by_title["Diagnostic reports"].action, "clean-directory-contents")
            self.assertEqual(by_title["Diagnostic reports"].risk, RiskLevel.SAFE)
            self.assertEqual(by_title["Crash reports"].action, "clean-directory-contents")
            self.assertEqual(by_title["Crash reports"].risk, RiskLevel.SAFE)
            self.assertEqual(by_title["App Store cache"].action, "clean-directory-contents")
            self.assertEqual(by_title["App Store cache"].risk, RiskLevel.MODERATE)
            self.assertEqual(by_title["Software Update cache"].action, "clean-directory-contents")
            self.assertEqual(by_title["Software Update cache"].risk, RiskLevel.MODERATE)

    def test_scan_reports_root_level_opera_runtime_caches(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            code_cache = home / "Library" / "Application Support" / "com.operasoftware.Opera" / "Code Cache"
            write_file(code_cache / "code.bin", 100)

            report = scan(ScanConfig(home=home, system_root=root, min_size=1))
            opera_cache = next(f for f in report.findings if f.title == "Opera Code Cache")

            self.assertEqual(opera_cache.path, str(code_cache))
            self.assertEqual(opera_cache.action, "clean-directory-contents")
            self.assertEqual(opera_cache.risk, RiskLevel.MODERATE)

    def test_scan_does_not_double_count_diagnostic_reports_under_user_logs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            write_file(home / "Library" / "Logs" / "DiagnosticReports" / "crash.crash", 100)

            report = scan(ScanConfig(home=home, system_root=root, min_size=1))
            titles = {finding.title for finding in report.findings}

            self.assertEqual(report.total_reclaimable_bytes, 100)
            self.assertNotIn("User logs", titles)

    def test_scan_does_not_double_count_app_store_cache_under_user_caches(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = root / "home"
            write_file(home / "Library" / "Caches" / "com.apple.appstore" / "download.bin", 100)

            report = scan(ScanConfig(home=home, system_root=root, min_size=1))
            titles = {finding.title for finding in report.findings}

            self.assertEqual(report.total_reclaimable_bytes, 100)
            self.assertNotIn("User caches", titles)

    def test_scan_does_not_double_count_precise_user_cache_findings(self):
        cases = (
            ("Homebrew cache", Path("Homebrew") / "download.bin"),
            ("Poetry cache", Path("pypoetry") / "artifact.bin"),
            ("uv cache", Path("uv") / "wheel.whl"),
            ("Go build cache", Path("go-build") / "obj"),
            ("Final Cut Pro cache", Path("com.apple.FinalCut") / "cache.bin"),
            ("Logic Pro cache", Path("com.apple.logic10") / "cache.bin"),
            ("Figma cache", Path("com.figma.Desktop") / "cache.bin"),
            ("Sketch cache", Path("com.bohemiancoding.sketch3") / "cache.bin"),
            ("Blender cache", Path("org.blenderfoundation.blender") / "cache.bin"),
            ("Unity Hub cache", Path("com.unity3d.UnityHub") / "cache.bin"),
        )
        for title, relative_path in cases:
            with self.subTest(title=title):
                with tempfile.TemporaryDirectory() as tmp:
                    root = Path(tmp)
                    home = root / "home"
                    write_file(home / "Library" / "Caches" / relative_path, 100)

                    report = scan(ScanConfig(home=home, system_root=root, min_size=1))
                    by_title = {finding.title: finding for finding in report.findings}

                    self.assertEqual(report.total_reclaimable_bytes, 100)
                    self.assertEqual(by_title[title].action, "clean-directory-contents")
                    self.assertNotIn("User caches", by_title)

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
