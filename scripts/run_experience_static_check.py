#!/usr/bin/env python3
"""
Python runner for experience_static_check.ps1.
Translates Assert-Pattern / Assert-NoPattern / Assert-MultilinePattern /
Assert-NoMultilinePattern / Assert-JsonFixtureIds / Assert-AcceptanceMatrix /
Assert-PageCopySnapshots / Assert-SignalFixtureRoles calls to rg/Python checks.
No PowerShell required.
"""
import re
import subprocess
import sys
import json
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).parent.parent
PS1 = Path(__file__).parent / "experience_static_check.ps1"

failures: list[str] = []
passed = 0


def convert_ps1_escapes(pattern: str) -> str:
    # Convert PS1 \x{HHHH} Unicode escapes to actual characters
    return re.sub(r'\\x\{([0-9A-Fa-f]+)\}',
                  lambda m: chr(int(m.group(1), 16)),
                  pattern)


def _smart_case_flags(pattern: str) -> int:
    # rg -S smart-case: if pattern has any uppercase letter outside of
    # escape sequences and character classes, use case-sensitive matching.
    # Strip escape sequences and char classes to check for literal uppercase.
    stripped = re.sub(r'\\[A-Za-z0-9]|\[(?:[^\]]|\\.)*\]', '', pattern)
    if any(c.isupper() for c in stripped):
        return re.UNICODE
    return re.IGNORECASE | re.UNICODE


def rg_search(pattern: str, path: str, multiline: bool = False) -> Optional[str]:
    """Search using Python re so we don't depend on shell rg function."""
    pattern = convert_ps1_escapes(pattern)
    target = ROOT / path
    flags = _smart_case_flags(pattern)
    if multiline:
        flags |= re.DOTALL
    try:
        if target.is_dir():
            # Recursively search all files
            matches = []
            for f in target.rglob("*"):
                if not f.is_file():
                    continue
                try:
                    text = f.read_text(encoding="utf-8", errors="replace")
                    if re.search(pattern, text, flags):
                        matches.append(str(f))
                except Exception:
                    pass
            return "\n".join(matches) if matches else None
        else:
            text = target.read_text(encoding="utf-8", errors="replace")
            m = re.search(pattern, text, flags)
            return m.group(0) if m else None
    except FileNotFoundError:
        return None


def assert_pattern(path: str, pattern: str, label: str) -> None:
    global passed
    if rg_search(pattern, path) is None:
        failures.append(f"FAIL [{label}]  Missing pattern in {path}")
    else:
        passed += 1


def assert_no_pattern(path: str, pattern: str, label: str) -> None:
    global passed
    result = rg_search(pattern, path)
    if result is not None:
        first = result.splitlines()[0]
        failures.append(f"FAIL [{label}]  Unexpected match in {path}: {first}")
    else:
        passed += 1


def assert_multiline_pattern(path: str, pattern: str, label: str) -> None:
    global passed
    if rg_search(pattern, path, multiline=True) is None:
        failures.append(f"FAIL [{label}]  Missing multiline pattern in {path}")
    else:
        passed += 1


def assert_no_multiline_pattern(path: str, pattern: str, label: str) -> None:
    global passed
    result = rg_search(pattern, path, multiline=True)
    if result is not None:
        first = result.splitlines()[0]
        failures.append(f"FAIL [{label}]  Unexpected multiline match in {path}: {first}")
    else:
        passed += 1


def assert_json_fixture_ids(path: str, ids: list[str], label: str) -> None:
    global passed
    target = ROOT / path
    try:
        items = json.loads(target.read_text(encoding="utf-8"))
        existing = {item["id"] for item in items if "id" in item}
        missing = [i for i in ids if i not in existing]
        if missing:
            failures.append(f"FAIL [{label}]  Missing fixture IDs in {path}: {missing}")
        else:
            passed += 1
    except Exception as e:
        failures.append(f"FAIL [{label}]  Error reading {path}: {e}")


def assert_acceptance_matrix(path: str, ids: list[str], label: str) -> None:
    global passed
    target = ROOT / path
    try:
        items = json.loads(target.read_text(encoding="utf-8"))
        existing = {item["id"] for item in items if "id" in item}
        missing = [i for i in ids if i not in existing]
        errors = []
        for item in items:
            iid = item.get("id", "?")
            for field in ("share_title_rule", "share_picture_rule", "playback_background_rule"):
                if not item.get(field):
                    errors.append(f"  Missing {field} for {iid}")
            if not item.get("forbidden_copy"):
                errors.append(f"  Missing forbidden_copy for {iid}")
        if missing or errors:
            failures.append(f"FAIL [{label}]  {path}: missing IDs={missing}; field errors={errors}")
        else:
            passed += 1
    except Exception as e:
        failures.append(f"FAIL [{label}]  Error reading {path}: {e}")


def assert_page_copy_snapshots(path: str, label: str) -> None:
    global passed
    target = ROOT / path
    try:
        items = json.loads(target.read_text(encoding="utf-8"))
        errors = []
        for item in items:
            iid = item.get("id", "?")
            for field in ("id", "surface", "source_paths", "evidence_required", "expected_copy", "forbidden_copy"):
                val = item.get(field)
                if not val or (isinstance(val, list) and len(val) == 0):
                    errors.append(f"  Missing {field} for snapshot {iid}")
                    continue
            source_paths = item.get("source_paths", [])
            combined = ""
            for sp in source_paths:
                sp_path = ROOT / sp
                if not sp_path.exists():
                    errors.append(f"  Missing source path for {iid}: {sp}")
                else:
                    combined += "\n" + sp_path.read_text(encoding="utf-8")
            for exp in item.get("expected_copy", []):
                if exp not in combined:
                    errors.append(f"  Missing expected copy for {iid}: {exp[:60]}")
            for forb in item.get("forbidden_copy", []):
                if forb in combined:
                    errors.append(f"  Forbidden copy found for {iid}: {forb[:60]}")
        if errors:
            failures.append(f"FAIL [{label}]  {path}:\n" + "\n".join(errors))
        else:
            passed += 1
    except Exception as e:
        failures.append(f"FAIL [{label}]  Error reading {path}: {e}")


def assert_signal_fixture_roles(path: str, label: str) -> None:
    global passed
    target = ROOT / path
    try:
        items = json.loads(target.read_text(encoding="utf-8"))
        errors = []
        for item in items:
            if item.get("category") == "signal":
                iid = item.get("id", "?")
                if not item.get("expected_title_role"):
                    errors.append(f"  Missing expected_title_role for {iid}")
                if not item.get("expected_picture_role"):
                    errors.append(f"  Missing expected_picture_role for {iid}")
        if errors:
            failures.append(f"FAIL [{label}]  {path}:\n" + "\n".join(errors))
        else:
            passed += 1
    except Exception as e:
        failures.append(f"FAIL [{label}]  Error reading {path}: {e}")


# ---------- PS1 parser ----------

def _unquote(s: str) -> str:
    """Strip surrounding single or double quotes from a PS1 argument."""
    s = s.strip()
    if (s.startswith("'") and s.endswith("'")) or (s.startswith('"') and s.endswith('"')):
        return s[1:-1]
    return s


def parse_and_run_ps1() -> None:
    """Parse experience_static_check.ps1 and execute each Assert-* call."""
    text = PS1.read_text(encoding="utf-8")

    # Split into logical lines (join continuation lines if any)
    lines = text.splitlines()

    i = 0
    while i < len(lines):
        line = lines[i].strip()
        i += 1

        # Multi-arg calls — collect until balanced single-quoted args
        if not line.startswith("Assert-"):
            continue

        # Accumulate the full call in case it spans nothing (all on one line)
        call = line
        # PS1 here doesn't use line continuation, each call is one line
        # Parse: Assert-FuncName 'arg1' 'arg2' ... 'label'
        # Use a simple tokeniser: pull quoted strings in order
        func_match = re.match(r"^(Assert-\S+)\s+(.*)", call, re.DOTALL)
        if not func_match:
            continue
        func = func_match.group(1)
        rest = func_match.group(2)

        # Tokenise single-quoted strings (PS1 style; no escaping of ' inside)
        tokens: list[str] = re.findall(r"'([^']*)'", rest)

        try:
            if func == "Assert-Pattern" and len(tokens) >= 3:
                assert_pattern(tokens[0], tokens[1], tokens[2])
            elif func == "Assert-NoPattern" and len(tokens) >= 3:
                assert_no_pattern(tokens[0], tokens[1], tokens[2])
            elif func == "Assert-MultilinePattern" and len(tokens) >= 3:
                assert_multiline_pattern(tokens[0], tokens[1], tokens[2])
            elif func == "Assert-NoMultilinePattern" and len(tokens) >= 3:
                assert_no_multiline_pattern(tokens[0], tokens[1], tokens[2])
            elif func == "Assert-JsonFixtureIds" and len(tokens) >= 3:
                ids = [t.strip() for t in tokens[1:-1]]
                assert_json_fixture_ids(tokens[0], ids, tokens[-1])
            elif func == "Assert-AcceptanceMatrix" and len(tokens) >= 3:
                ids = [t.strip() for t in tokens[1:-1]]
                assert_acceptance_matrix(tokens[0], ids, tokens[-1])
            elif func == "Assert-PageCopySnapshots" and len(tokens) >= 2:
                assert_page_copy_snapshots(tokens[0], tokens[1])
            elif func == "Assert-SignalFixtureRoles" and len(tokens) >= 2:
                assert_signal_fixture_roles(tokens[0], tokens[1])
        except Exception as e:
            failures.append(f"FAIL [{func}]  Exception: {e}")


if __name__ == "__main__":
    parse_and_run_ps1()
    total = passed + len(failures)
    if failures:
        print(f"\nexperience_static_check: {len(failures)} FAILURES / {total} checks")
        for f in failures:
            print(f)
        sys.exit(1)
    else:
        print(f"experience_static_check: OK  ({passed} checks passed)")
        sys.exit(0)
