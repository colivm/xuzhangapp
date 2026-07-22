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
        "本机规则始终先生成",
        "日/周/月轻总结会在账本变化后尝试提前润色",
        "AI 指令台和生活线索仍不联网",
    ),
    "NativeDemoApp/Views/MemberPricingView.swift": (
        "AI 指令台不联网",
        "本机规则会先按日期、分类、备注和上下文整理",
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

    report_source = (ROOT / "NativeDemoApp/Services/AIReportService.swift").read_text(encoding="utf-8")
    proxy_source = (ROOT / "ai-proxy/server.js").read_text(encoding="utf-8")
    contract_source = (ROOT / "ai-proxy/narrativeRewriteContract.js").read_text(encoding="utf-8")
    legacy_contract_source = (ROOT / "ai-proxy/legacyInsightContract.js").read_text(encoding="utf-8")
    feature_policy_source = (ROOT / "ai-proxy/aiFeaturePolicy.js").read_text(encoding="utf-8")
    contract_test_source = (ROOT / "ai-proxy/narrativeRewriteContract.test.js").read_text(encoding="utf-8")
    runtime_policy_source = (ROOT / "ai-proxy/runtimeEnvironmentPolicy.js").read_text(encoding="utf-8")
    runtime_policy_test_source = (ROOT / "ai-proxy/runtimeEnvironmentPolicy.test.js").read_text(encoding="utf-8")
    backend_source = (ROOT / "backend/src/server.js").read_text(encoding="utf-8")
    narrative_client_start = report_source.index("func generateNarrativeRewrites")
    narrative_client_end = report_source.index("func generateInsight", narrative_client_start)
    narrative_client_source = report_source[narrative_client_start:narrative_client_end]
    narrative_contract_checks = {
        "client sends structured fact packs only through a proxy": (
            '"factPacks": factPackPayload' in narrative_client_source
            and '"feature": "narrative_rewrite_batch"' in narrative_client_source
            and '"messages"' not in narrative_client_source
            and "AppSettings.productionAIEndpoint" in report_source
            and "open.bigmodel.cn" not in report_source
            and "x-proxy-token" not in report_source
        ),
        "proxy validates narrative input before model use": (
            'feature === "narrative_rewrite_batch"' in proxy_source
            and "validateNarrativeFactPacks(req.body?.factPacks)" in proxy_source
        ),
        "proxy preserves the legacy insight response branch": (
            ": normalizeInsightPayload(content)" in proxy_source
            and "function normalizeInsightPayload" in legacy_contract_source
        ),
        "proxy owns the narrative prompt and fixed temperature": (
            "buildNarrativeRewriteMessages(req.body?.factPacks, req.body?.tone)" in proxy_source
            and '? 0.25' in proxy_source
            and "function buildNarrativeRewriteMessages" in contract_source
        ),
        "proxy owns the upstream model selection": (
            'const model = (AI_UPSTREAM_MODEL || "glm-4-flash").toString()' in proxy_source
            and "req.body?.model" not in proxy_source
        ),
        "production does not register the development token route": (
            "if (DEVELOPMENT_ROUTES_ENABLED)" in proxy_source
            and "allowsDevelopmentRoutes(process.env.NODE_ENV)" in proxy_source
            and "function allowsDevelopmentRoutes" in runtime_policy_source
            and 'allowsDevelopmentRoutes("production"), false' in runtime_policy_test_source
        ),
        "proxy rejects unknown feature names before rate limiting": (
            "normalizedSupportedFeature(req.body?.feature)" in proxy_source
            and "UNSUPPORTED_FEATURE" in proxy_source
            and "narrative_rewrite_batch" in feature_policy_source
            and "return SUPPORTED_FEATURES.has(feature) ? feature : null" in feature_policy_source
        ),
        "proxy validates evidence scope period and numbers": all(
            token in contract_source
            for token in (
                "ALLOWED_SCOPES",
                "periodKey !== pack.periodKey",
                "evidenceIDs.includes(leadFactID)",
                "numbersIn(combined)",
                "user text must remain redacted",
                "photo fact must remain redacted",
            )
        ),
        "proxy contract has executable legacy and narrative coverage": all(
            token in contract_test_source
            for token in (
                "accepts a valid evidence-backed narrative rewrite batch",
                "rejects unknown evidence, mismatched periods, and invented numbers",
                "keeps the legacy daily insight response contract unchanged",
            )
        ),
        "backend continues to forward the complete protected request body": (
            'app.post("/v1/ai/insight/daily", requireAuth' in backend_source
            and "body: JSON.stringify(req.body || {})" in backend_source
        ),
    }
    for description, passed in narrative_contract_checks.items():
        if not passed:
            print(f"narrative AI proxy contract missing: {description}")
            return 1

    print("ai_capability_lint: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
