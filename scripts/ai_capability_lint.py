#!/usr/bin/env python3
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]

REQUIRED = {
    "AI_CAPABILITY_CONTRACT_v1.md": (
        "AI 指令台",
        "本机规则引擎",
        "今日小记",
        "月度整理",
        "远程模型未接通，已用本地规则",
        "不支持的开放问题必须返回",
    ),
    "NativeDemoApp/Views/InsightWebView.swift": (
        "按账本规则查、比、补",
        "本机规则 · 不联网",
        "正在按本机规则整理",
        "正在尝试远程模型",
        "远程模型已生成",
        "本地规则已生成",
        "远程模型未接通，已用本地规则",
    ),
    "NativeDemoApp/Views/SettingsView.swift": (
        "只影响今日小记和月度整理",
        "AI 指令台、周记、月章和生活线索始终在本机处理",
    ),
    "NativeDemoApp/Views/MemberPricingView.swift": (
        "AI 指令台不联网",
        "本机规则会按日期、分类、备注和上下文整理",
    ),
    "NativeDemoApp/Models/HomeItem.swift": ('case .ocr: return "账单识别"',),
    "NativeDemoApp/Views/RecordView.swift": ('case ocr = "账单识别"',),
}

FORBIDDEN_VISIBLE_COPY = (
    "先理解、再预览",
    "我理解的是",
    "智能导入记录",
    "AI 会长期",
    "AI 正在持续",
    "AI 将继续",
    "AI 能整理",
    "已回退本地建议",
    "远程 AI",
    "AI 服务地址配置异常",
    "AI 请求失败",
)

STRING_LITERAL = re.compile(r'"(?:\\.|[^"\\])*"')


def main() -> int:
    for relative_path, required_values in REQUIRED.items():
        text = (ROOT / relative_path).read_text(encoding="utf-8")
        for required in required_values:
            if required not in text:
                print(f"{relative_path}: missing `{required}`")
                return 1

    for path in sorted((ROOT / "NativeDemoApp").rglob("*.swift")):
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            for literal in STRING_LITERAL.findall(line):
                for forbidden in FORBIDDEN_VISIBLE_COPY:
                    if forbidden in literal:
                        print(
                            f"{path.relative_to(ROOT)}:{line_number}: overclaimed AI copy `{forbidden}` in {literal}"
                        )
                        return 1

    insight_source = (ROOT / "NativeDemoApp/Views/InsightWebView.swift").read_text(encoding="utf-8")
    engine_start = insight_source.index("private final class AICommandEngine")
    engine_end = insight_source.index("private func saveSingleAICommandDraft", engine_start)
    engine_source = insight_source[engine_start:engine_end]
    for forbidden_dependency in ("AIReportService", "URLSession", "useRemoteAI", "aiEndpoint"):
        if forbidden_dependency in engine_source:
            print(f"AICommandEngine unexpectedly depends on `{forbidden_dependency}`")
            return 1

    print("ai_capability_lint: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
