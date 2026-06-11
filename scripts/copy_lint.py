#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

DEFAULT_TARGETS = [
    "NativeDemoApp/Services/EchoAnchorService.swift",
    "NativeDemoApp/Services/MerchantBrandCatalog.swift",
    "NativeDemoApp/Services/NarrativeCopyResolver.swift",
    "NativeDemoApp/Services/PetCompanionCopy.swift",
    "NativeDemoApp/Services/PlaybackCopyPool.swift",
    "NativeDemoApp/Services/ScenePackCopyPool.swift",
    "NativeDemoApp/ContentView.swift",
    "NativeDemoApp/Info.plist",
    "NativeDemoApp/ViewModels/HomeViewModel.swift",
    "NativeDemoApp/Views/InsightWebView.swift",
    "NativeDemoApp/Views/MinimalOnboardingSheet.swift",
    "NativeDemoApp/Views/RecordView.swift",
    "NativeDemoApp/Views/SettingsView.swift",
]

BLOCKED_TERMS = [
    "小确幸",
    "治愈",
    "你值得",
    "被看见",
    "掌控感",
    "生活像流水",
    "忙碌与温柔",
    "好好收下",
    "生活角落",
    "生活底色",
    "生活拼图",
    "顺带记下",
    "被接住",
    "接住",
    "高光",
    "小奖励",
    "小快乐",
]

SOFT_TERMS = [
    "温柔",
    "慢慢",
    "好好",
    "顺手",
    "值得",
    "松弛",
    "照顾",
    "安顿",
    "收下",
    "轮廓",
]

SANITIZER_FUNC_NAMES = [
    "sanitizeLifeNote",
    "sanitizeBrandNote",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Lint user-visible Chinese copy for high-risk abstract phrases."
    )
    parser.add_argument(
        "paths",
        nargs="*",
        help="Optional files or directories to scan. Defaults to iOS copy-bearing files.",
    )
    parser.add_argument(
        "--strict-soft",
        action="store_true",
        help="Treat soft terms as failures instead of warnings.",
    )
    return parser.parse_args()


def expand_paths(raw_paths: list[str]) -> list[Path]:
    if not raw_paths:
        return [ROOT / path for path in DEFAULT_TARGETS]

    files: list[Path] = []
    for raw in raw_paths:
        path = Path(raw)
        if not path.is_absolute():
            path = ROOT / path
        path = path.resolve()
        if path.is_dir():
            files.extend(sorted(p for p in path.rglob("*.swift") if p.is_file()))
            files.extend(sorted(p for p in path.rglob("*.md") if p.is_file()))
        elif path.is_file():
            files.append(path)
    return files


def sanitizer_ranges(lines: list[str]) -> set[int]:
    ignored: set[int] = set()
    for start_index, line in enumerate(lines):
        if not any(f"func {name}" in line for name in SANITIZER_FUNC_NAMES):
            continue
        brace_depth = line.count("{") - line.count("}")
        if brace_depth <= 0:
            continue
        ignored.add(start_index)
        for index in range(start_index + 1, len(lines)):
            ignored.add(index)
            brace_depth += lines[index].count("{") - lines[index].count("}")
            if brace_depth <= 0:
                break
    return ignored


def should_ignore_line(line: str, index: int, ignored_ranges: set[int]) -> bool:
    stripped = line.strip()
    if index in ignored_ranges:
        return True
    if ".replacingOccurrences(of:" in stripped:
        return True
    if stripped.startswith("//"):
        return True
    return False


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT)).replace("\\", "/")
    except ValueError:
        return str(path)


def scan_file(path: Path, strict_soft: bool) -> tuple[list[str], list[str]]:
    failures: list[str] = []
    warnings: list[str] = []

    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        text = path.read_text(encoding="utf-8-sig")

    lines = text.splitlines()
    ignored_ranges = sanitizer_ranges(lines)

    for index, line in enumerate(lines):
        if should_ignore_line(line, index, ignored_ranges):
            continue
        location = f"{display_path(path)}:{index + 1}"
        for term in BLOCKED_TERMS:
            if term in line:
                failures.append(f"{location}: blocked term `{term}`")
        for term in SOFT_TERMS:
            if term in line:
                message = f"{location}: soft term `{term}`"
                if strict_soft:
                    failures.append(message)
                else:
                    warnings.append(message)

    return failures, warnings


def main() -> int:
    args = parse_args()
    files = expand_paths(args.paths)
    if not files:
        print("copy-lint: no files to scan", file=sys.stderr)
        return 2

    all_failures: list[str] = []
    all_warnings: list[str] = []
    for path in files:
        failures, warnings = scan_file(path, strict_soft=args.strict_soft)
        all_failures.extend(failures)
        all_warnings.extend(warnings)

    for warning in all_warnings:
        print(f"warning: {warning}")
    for failure in all_failures:
        print(f"error: {failure}", file=sys.stderr)

    if all_failures:
        print(
            f"copy-lint failed: {len(all_failures)} error(s), {len(all_warnings)} warning(s)",
            file=sys.stderr,
        )
        return 1

    print(f"copy-lint passed: scanned {len(files)} file(s), {len(all_warnings)} warning(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
