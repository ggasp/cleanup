from __future__ import annotations

import json
import sys
from typing import TextIO

from .models import ScanReport, format_bytes

try:
    from rich.console import Console
    from rich.table import Table
except ImportError:  # pragma: no cover - exercised only without optional dependency
    Console = None
    Table = None


def render_json(report: ScanReport, stream: TextIO | None = None) -> None:
    stream = stream or sys.stdout
    print(json.dumps(report.to_dict(), indent=2), file=stream)


def render_scan(report: ScanReport, *, stream: TextIO | None = None) -> None:
    stream = stream or sys.stdout
    if Console is not None and Table is not None:
        console = Console(file=stream)
        table = Table(title="MacBook Disk Maintenance Scan")
        table.add_column("Risk", no_wrap=True)
        table.add_column("Category")
        table.add_column("Finding")
        table.add_column("Size", justify="right")
        table.add_column("Action")
        for finding in report.sorted_findings():
            table.add_row(
                finding.risk.value,
                finding.category,
                finding.title,
                format_bytes(finding.bytes_reclaimable),
                finding.action or "review",
            )
        console.print(table)
        console.print(f"Total visible opportunity: [bold]{format_bytes(report.total_reclaimable_bytes)}[/bold]")
        return

    print("MacBook Disk Maintenance Scan", file=stream)
    for finding in report.sorted_findings():
        print(
            f"{finding.risk.value:8} {finding.category:14} {format_bytes(finding.bytes_reclaimable):>10} "
            f"{finding.title} ({finding.action or 'review'})",
            file=stream,
        )
    print(f"Total visible opportunity: {format_bytes(report.total_reclaimable_bytes)}", file=stream)


def render_doctor(report: ScanReport, *, stream: TextIO | None = None) -> None:
    stream = stream or sys.stdout
    safe_count = sum(1 for finding in report.findings if finding.risk.value == "SAFE")
    moderate_count = sum(1 for finding in report.findings if finding.risk.value == "MODERATE")
    high_count = sum(1 for finding in report.findings if finding.risk.value == "HIGH")
    if Console is not None:
        console = Console(file=stream)
        console.print("[bold]MacBook Storage Doctor[/bold]")
        console.print(f"Total visible opportunity: [bold]{format_bytes(report.total_reclaimable_bytes)}[/bold]")
        console.print(f"Safe: {safe_count}  Moderate: {moderate_count}  High: {high_count}")
        if high_count:
            console.print("[yellow]High-risk items need manual review. No automatic cleanup is enabled for them.[/yellow]")
        return
    print("MacBook Storage Doctor", file=stream)
    print(f"Total visible opportunity: {format_bytes(report.total_reclaimable_bytes)}", file=stream)
    print(f"Safe: {safe_count}  Moderate: {moderate_count}  High: {high_count}", file=stream)
