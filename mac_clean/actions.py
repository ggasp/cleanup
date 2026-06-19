from __future__ import annotations

import shutil
import subprocess
from dataclasses import dataclass
from fnmatch import fnmatch
from pathlib import Path

from .models import Finding, RiskLevel
from .scanner import directory_size


@dataclass(frozen=True)
class ActionContext:
    dry_run: bool = False
    yes_safe: bool = False
    fresh_start: bool = False
    deep_clean: bool = False


@dataclass(frozen=True)
class ActionResult:
    action: str
    path: str
    bytes_reclaimed: int
    dry_run: bool
    message: str


DOWNLOAD_INSTALLER_PATTERNS = ("*.dmg", "*.pkg", "*.iso", "Install macOS*.app")
COMMAND_ACTIONS: dict[str, tuple[str, ...]] = {
    "run-xcrun-simctl-delete-unavailable": ("/usr/bin/xcrun", "simctl", "delete", "unavailable"),
}


def clean_directory_contents(path: Path, context: ActionContext) -> ActionResult:
    target = path.expanduser()
    _ensure_cleanable_directory(target)
    bytes_before = directory_size(target)
    if context.dry_run:
        return ActionResult("clean-directory", str(target), bytes_before, True, "Dry run: no files deleted.")

    for child in list(target.iterdir()):
        if child.is_dir() and not child.is_symlink():
            shutil.rmtree(child, ignore_errors=True)
        else:
            try:
                child.unlink()
            except FileNotFoundError:
                pass
    bytes_after = directory_size(target)
    return ActionResult(
        "clean-directory",
        str(target),
        max(0, bytes_before - bytes_after),
        False,
        "Directory contents cleaned.",
    )


def remove_matching_children(path: Path, patterns: tuple[str, ...], context: ActionContext) -> ActionResult:
    target = path.expanduser()
    _ensure_cleanable_directory(target)
    matches = [child for child in target.iterdir() if any(fnmatch(child.name, pattern) for pattern in patterns)]
    bytes_before = sum(directory_size(child) for child in matches)
    if context.dry_run:
        return ActionResult("remove-matching-children", str(target), bytes_before, True, "Dry run: no files deleted.")

    for child in matches:
        if child.is_dir() and not child.is_symlink():
            shutil.rmtree(child, ignore_errors=True)
        else:
            try:
                child.unlink()
            except FileNotFoundError:
                pass
    bytes_after = sum(directory_size(child) for child in matches if child.exists())
    return ActionResult(
        "remove-matching-children",
        str(target),
        max(0, bytes_before - bytes_after),
        False,
        "Matching children removed.",
    )


def clean_known_subdirs(path: Path, names: tuple[str, ...], context: ActionContext) -> ActionResult:
    target = path.expanduser()
    _ensure_cleanable_directory(target)
    matches = [child for child in target.iterdir() if child.name in names and child.is_dir() and not child.is_symlink()]
    bytes_before = sum(directory_size(child) for child in matches)
    if context.dry_run:
        return ActionResult("clean-known-subdirs", str(target), bytes_before, True, "Dry run: no files deleted.")

    for child in matches:
        shutil.rmtree(child, ignore_errors=True)
    bytes_after = sum(directory_size(child) for child in matches if child.exists())
    return ActionResult(
        "clean-known-subdirs",
        str(target),
        max(0, bytes_before - bytes_after),
        False,
        "Known cache subdirectories cleaned.",
    )


def remove_path(path: Path, context: ActionContext) -> ActionResult:
    target = path.expanduser()
    _ensure_removable_path(target)
    bytes_before = directory_size(target)
    if context.dry_run:
        return ActionResult("remove-path", str(target), bytes_before, True, "Dry run: no files deleted.")

    if target.is_dir() and not target.is_symlink():
        shutil.rmtree(target, ignore_errors=True)
    else:
        try:
            target.unlink()
        except FileNotFoundError:
            pass
    return ActionResult(
        "remove-path",
        str(target),
        bytes_before if not target.exists() else max(0, bytes_before - directory_size(target)),
        False,
        "Path removed.",
    )


def run_command_action(action: str, context: ActionContext) -> ActionResult | None:
    command = COMMAND_ACTIONS.get(action)
    if command is None:
        return None
    command_text = " ".join(command)
    if context.dry_run:
        return ActionResult(action, command_text, 0, True, f"Would run: {command_text}")
    try:
        completed = subprocess.run(command, check=False, capture_output=True, text=True)
    except OSError as error:
        return ActionResult(action, command_text, 0, False, f"Command could not be run: {error}")
    if completed.returncode == 0:
        message = "Command completed."
    else:
        stderr = completed.stderr.strip()
        message = (
            f"Command exited with {completed.returncode}: {stderr}"
            if stderr
            else f"Command exited with {completed.returncode}."
        )
    return ActionResult(action, command_text, 0, False, message)


def run_safe_actions(findings: list[Finding], context: ActionContext) -> list[ActionResult]:
    results: list[ActionResult] = []
    for finding in findings:
        if finding.risk != RiskLevel.SAFE or finding.action is None:
            continue
        if not context.yes_safe:
            continue
        if finding.action in {"clean-trash", "clean-user-caches"}:
            result = clean_directory_contents(Path(finding.path), context)
            results.append(
                ActionResult(finding.action, result.path, result.bytes_reclaimed, result.dry_run, result.message)
            )
    return results


def run_fresh_start_actions(findings: list[Finding], context: ActionContext) -> list[ActionResult]:
    if not context.fresh_start:
        return []
    return _run_safe_and_moderate_actions(findings, context)


def run_deep_clean_actions(findings: list[Finding], context: ActionContext) -> list[ActionResult]:
    if not context.deep_clean:
        return []
    results: list[ActionResult] = []
    for finding in findings:
        if finding.risk not in {RiskLevel.SAFE, RiskLevel.MODERATE} or finding.action is None:
            continue
        result = _run_action_for_finding(finding, context)
        if result is not None:
            results.append(result)
    return results


def _run_safe_and_moderate_actions(findings: list[Finding], context: ActionContext) -> list[ActionResult]:
    results: list[ActionResult] = []
    for finding in findings:
        if finding.risk not in {RiskLevel.SAFE, RiskLevel.MODERATE} or finding.action is None:
            continue
        result = _run_action_for_finding(finding, context)
        if result is not None:
            results.append(result)
    return results


def _run_action_for_finding(finding: Finding, context: ActionContext) -> ActionResult | None:
    if finding.action in COMMAND_ACTIONS:
        return run_command_action(finding.action, context)
    if finding.action.startswith("run-"):
        return None
    path = Path(finding.path)
    if not path.exists():
        return ActionResult(finding.action, str(path), 0, context.dry_run, "Path already absent.")
    if finding.action in {"clean-trash", "clean-user-caches", "clean-directory-contents"}:
        result = clean_directory_contents(path, context)
    elif finding.action == "remove-download-installers":
        result = remove_matching_children(path, DOWNLOAD_INSTALLER_PATTERNS, context)
    elif finding.action == "remove-path":
        result = remove_path(path, context)
    elif finding.action == "clean-electron-cache-subdirs":
        result = clean_known_subdirs(path, ("Cache", "Code Cache", "GPUCache", "Service Worker"), context)
    else:
        return None
    return ActionResult(finding.action, result.path, result.bytes_reclaimed, result.dry_run, result.message)


def _ensure_cleanable_directory(path: Path) -> None:
    resolved = path.resolve(strict=False)
    protected = {
        Path("/").resolve(strict=False),
        Path("/System").resolve(strict=False),
        Path("/Library").resolve(strict=False),
        Path("/Applications").resolve(strict=False),
        Path.home().resolve(strict=False),
    }
    if resolved in protected:
        raise ValueError(f"Refusing to clean protected path: {path}")
    if not path.exists():
        raise ValueError(f"Path does not exist: {path}")
    if not path.is_dir():
        raise ValueError(f"Path is not a directory: {path}")


def _ensure_removable_path(path: Path) -> None:
    resolved = path.resolve(strict=False)
    protected = {
        Path("/").resolve(strict=False),
        Path("/System").resolve(strict=False),
        Path("/Library").resolve(strict=False),
        Path("/Applications").resolve(strict=False),
        Path.home().resolve(strict=False),
    }
    if resolved in protected:
        raise ValueError(f"Refusing to remove protected path: {path}")
    if not path.exists():
        raise ValueError(f"Path does not exist: {path}")
