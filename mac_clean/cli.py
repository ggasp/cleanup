from __future__ import annotations

import argparse
from pathlib import Path

from .actions import ActionContext, ActionResult, run_deep_clean_actions, run_fresh_start_actions, run_safe_actions
from .models import format_bytes
from .reporters import render_doctor, render_json, render_scan
from .scanner import ScanConfig, scan


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    command = args.command or "scan"

    config = ScanConfig(
        home=Path(args.home).expanduser(),
        system_root=Path(args.system_root),
        min_size=parse_size(args.min_size),
        large_file_threshold=parse_size(args.large_file_threshold),
    )
    report = scan(config)

    if command in {"scan", "report"}:
        if args.json_output:
            render_json(report)
        else:
            render_scan(report)
        return 0

    if command == "doctor":
        render_doctor(report)
        return 0

    if command == "clean":
        if args.json_output:
            render_json(report)
        else:
            render_scan(report)
        context = ActionContext(dry_run=args.dry_run, yes_safe=args.yes_safe)
        results = run_safe_actions(report.findings, context)
        for result in results:
            print(format_action_result(result))
        if not args.yes_safe:
            print("No cleanup performed. Pass --yes-safe to clean SAFE findings.")
        return 0

    if command == "fresh-start":
        if args.json_output:
            render_json(report)
        else:
            render_scan(report)
        if args.i_understand != "fresh-start":
            print("No cleanup performed. Pass --i-understand fresh-start to clean SAFE and actionable MODERATE findings.")
            return 2
        context = ActionContext(dry_run=args.dry_run, yes_safe=True, fresh_start=True)
        results = run_fresh_start_actions(report.findings, context)
        for result in results:
            print(format_action_result(result))
        return 0

    if command == "deep-clean":
        if args.json_output:
            render_json(report)
        else:
            render_scan(report)
        if args.i_understand != "deep-clean":
            print("No cleanup performed. Pass --i-understand deep-clean to clean aggressive SAFE and MODERATE findings.")
            return 2
        context = ActionContext(dry_run=args.dry_run, yes_safe=True, fresh_start=True, deep_clean=True)
        results = run_deep_clean_actions(report.findings, context)
        for result in results:
            print(format_action_result(result))
        return 0

    parser.error(f"Unknown command: {command}")
    return 2


def format_action_result(result: ActionResult) -> str:
    verb = "Would reclaim" if result.dry_run else "Reclaimed"
    line = f"{verb} {format_bytes(result.bytes_reclaimed)} from {result.path}"
    if result.message:
        line = f"{line} - {result.message}"
    return line


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="cleanup.py",
        description="Scan and safely clean macOS disk-space pressure points.",
    )
    subparsers = parser.add_subparsers(dest="command")
    for name in ("scan", "report", "doctor", "clean", "fresh-start", "deep-clean"):
        subparser = subparsers.add_parser(name)
        add_common_arguments(subparser)
        if name in {"scan", "report", "clean", "fresh-start", "deep-clean"}:
            subparser.add_argument("--json", action="store_true", dest="json_output", help="Emit JSON output.")
        else:
            subparser.set_defaults(json_output=False)
        if name in {"clean", "fresh-start", "deep-clean"}:
            subparser.add_argument("--dry-run", action="store_true", help="Show cleanup actions without deleting.")
        else:
            subparser.set_defaults(dry_run=False)
        if name == "clean":
            subparser.add_argument("--yes-safe", action="store_true", help="Clean SAFE findings without prompts.")
        elif name == "fresh-start":
            subparser.add_argument(
                "--i-understand",
                default="",
                help="Required keyword for fresh-start cleanup: fresh-start.",
            )
            subparser.set_defaults(yes_safe=False)
        elif name == "deep-clean":
            subparser.add_argument(
                "--i-understand",
                default="",
                help="Required keyword for deep-clean cleanup: deep-clean.",
            )
            subparser.set_defaults(yes_safe=False)
        else:
            subparser.set_defaults(yes_safe=False)

    parser.set_defaults(
        command="scan",
        home=str(Path.home()),
        system_root="/",
        min_size="0B",
        large_file_threshold="1GiB",
        json_output=False,
        dry_run=False,
        yes_safe=False,
    )
    return parser


def add_common_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--home", default=str(Path.home()), help=argparse.SUPPRESS)
    parser.add_argument("--system-root", default="/", help=argparse.SUPPRESS)
    parser.add_argument("--min-size", default="0B", help="Hide findings smaller than this size, e.g. 500M.")
    parser.add_argument("--large-file-threshold", default="1GiB", help="Threshold for large-file findings.")


def parse_size(value: str) -> int:
    text = value.strip()
    if not text:
        raise argparse.ArgumentTypeError("Size cannot be empty.")
    units = {
        "B": 1,
        "K": 1024,
        "KB": 1024,
        "KIB": 1024,
        "M": 1024**2,
        "MB": 1024**2,
        "MIB": 1024**2,
        "G": 1024**3,
        "GB": 1024**3,
        "GIB": 1024**3,
        "T": 1024**4,
        "TB": 1024**4,
        "TIB": 1024**4,
    }
    number = ""
    suffix = ""
    for char in text:
        if char.isdigit() or char == ".":
            number += char
        else:
            suffix += char
    if not number:
        raise argparse.ArgumentTypeError(f"Invalid size: {value}")
    suffix = suffix.strip().upper() or "B"
    if suffix not in units:
        raise argparse.ArgumentTypeError(f"Invalid size unit: {suffix}")
    return int(float(number) * units[suffix])
