from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any


class RiskLevel(str, Enum):
    SAFE = "SAFE"
    MODERATE = "MODERATE"
    HIGH = "HIGH"


def format_bytes(value: int) -> str:
    value = max(0, int(value))
    units = ("B", "KiB", "MiB", "GiB", "TiB")
    amount = float(value)
    for unit in units:
        if amount < 1024 or unit == units[-1]:
            if unit == "B":
                return f"{int(amount)} B"
            return f"{amount:.1f} {unit}"
        amount /= 1024
    return f"{value} B"


@dataclass(frozen=True)
class Finding:
    category: str
    title: str
    path: str
    bytes_reclaimable: int
    risk: RiskLevel
    action: str | None = None
    detail: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "category": self.category,
            "title": self.title,
            "path": self.path,
            "bytes": self.bytes_reclaimable,
            "size": format_bytes(self.bytes_reclaimable),
            "risk": self.risk.value,
            "action": self.action,
            "detail": self.detail,
        }


@dataclass(frozen=True)
class ScanReport:
    findings: list[Finding] = field(default_factory=list)
    generated_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())

    @property
    def total_reclaimable_bytes(self) -> int:
        return sum(finding.bytes_reclaimable for finding in self.findings)

    def sorted_findings(self) -> list[Finding]:
        return sorted(self.findings, key=lambda finding: finding.bytes_reclaimable, reverse=True)

    def filtered(self, min_size: int) -> "ScanReport":
        return ScanReport(
            findings=[finding for finding in self.findings if finding.bytes_reclaimable >= min_size],
            generated_at=self.generated_at,
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "generated_at": self.generated_at,
            "total_bytes": self.total_reclaimable_bytes,
            "total_size": format_bytes(self.total_reclaimable_bytes),
            "findings": [finding.to_dict() for finding in self.sorted_findings()],
        }
