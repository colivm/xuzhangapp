#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / "NativeDemoApp"

DEPRECATED_ALIASES = (
    "今日生活回放",
    "本周回放",
    "本月回放",
    "月度回放",
    "周回放",
    "周切片",
    "周章",
    "本月章",
    "生活印记",
    "深度线索",
    "AI生活助手",
    "AI 生活助手",
    "想多聊一句",
    "多聊一句",
    "继续解读",
    "月度回顾",
    "月度复盘",
    "生活回放",
    "保存月记",
    "月记会",
    "月记语气",
    "写成一段月记",
    "月记先",
)

STRING_LITERAL = re.compile(r'"(?:\\.|[^"\\])*"')

REQUIRED_CANONICAL_COPY = {
    "PRODUCT_TERMINOLOGY_v1.md": ("今日回放", "周记", "月章", "生活线索", "AI 指令台", "继续问", "月度整理"),
    "NativeDemoApp/Services/PlaybackService.swift": ('let title = "周记"', 'let title = "月章"'),
    "NativeDemoApp/Views/InsightWebView.swift": ('navigationTitle("AI 指令台")', "查记录", "做对比", "补遗漏"),
    "NativeDemoApp/Views/SummaryPlaybackSheet.swift": ('? "周记" : "月章"', 'Text("继续问")'),
}


def main() -> int:
    failures: list[str] = []
    scanned = 0
    for path in sorted(SOURCE_ROOT.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        scanned += 1
        for line_number, line in enumerate(text.splitlines(), start=1):
            literals = STRING_LITERAL.findall(line)
            for literal in literals:
                for alias in DEPRECATED_ALIASES:
                    if alias in literal:
                        failures.append(
                            f"{path.relative_to(ROOT)}:{line_number}: deprecated term `{alias}` in {literal}"
                        )

    if failures:
        print("\n".join(failures))
        return 1
    for relative_path, required_values in REQUIRED_CANONICAL_COPY.items():
        text = (ROOT / relative_path).read_text(encoding="utf-8")
        for required in required_values:
            if required not in text:
                print(f"{relative_path}: missing canonical copy `{required}`")
                return 1
    print(f"terminology_lint: OK ({scanned} Swift files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
