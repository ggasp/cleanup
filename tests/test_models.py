import json
import unittest

from mac_clean.models import Finding, RiskLevel, ScanReport, format_bytes


class ModelTests(unittest.TestCase):
    def test_format_bytes_uses_human_units(self):
        self.assertEqual(format_bytes(0), "0 B")
        self.assertEqual(format_bytes(1023), "1023 B")
        self.assertEqual(format_bytes(1024), "1.0 KiB")
        self.assertEqual(format_bytes(1536), "1.5 KiB")
        self.assertEqual(format_bytes(5 * 1024 * 1024), "5.0 MiB")

    def test_finding_serializes_to_json_safe_dict(self):
        finding = Finding(
            category="Caches",
            title="User cache",
            path="/Users/example/Library/Caches",
            bytes_reclaimable=2048,
            risk=RiskLevel.SAFE,
            action="clean-user-cache",
            detail="Regenerable app cache files.",
        )

        payload = finding.to_dict()

        self.assertEqual(payload["risk"], "SAFE")
        self.assertEqual(payload["size"], "2.0 KiB")
        self.assertEqual(payload["bytes"], 2048)
        self.assertEqual(payload["action"], "clean-user-cache")
        json.dumps(payload)

    def test_scan_report_sorts_by_size_and_totals(self):
        report = ScanReport(
            findings=[
                Finding("Small", "Small item", "/tmp/small", 10, RiskLevel.SAFE),
                Finding("Large", "Large item", "/tmp/large", 200, RiskLevel.MODERATE),
            ]
        )

        sorted_findings = report.sorted_findings()

        self.assertEqual(sorted_findings[0].title, "Large item")
        self.assertEqual(report.total_reclaimable_bytes, 210)
        self.assertEqual(report.to_dict()["total_size"], "210 B")


if __name__ == "__main__":
    unittest.main()
