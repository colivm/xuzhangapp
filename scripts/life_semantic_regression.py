#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LEXICON_PATH = ROOT / "NativeDemoApp/Resources/RecordSceneLexicon.json"
REGRESSION_CASES_PATH = ROOT / "NativeDemoApp/Resources/RecordSceneLexicon.regression.json"

SWIFT_FILES = {
    "brands": "NativeDemoApp/Services/MerchantBrandCatalog.swift",
    "semantic_fallback": "NativeDemoApp/Models/HomeItem.swift",
    "life_scene": "NativeDemoApp/Services/LifeSceneSemanticService.swift",
    "life_mark": "NativeDemoApp/Services/LifeMarkService.swift",
    "record_view": "NativeDemoApp/Views/RecordView.swift",
    "scene_pack": "NativeDemoApp/Services/ScenePackCopyPool.swift",
    "home_view": "NativeDemoApp/Views/HomeView.swift",
    "insight_web_view": "NativeDemoApp/Views/InsightWebView.swift",
    "memory_context": "NativeDemoApp/Services/RecordMemoryContextService.swift",
}

EXPECTED_JSON_KEYWORDS = {
    "keywordRules:餐饮": [
        "茶叶蛋", "饭团", "关东煮", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴",
        "海底捞", "老乡鸡", "塔斯汀", "库迪", "库迪咖啡", "绝味", "袁记云饺", "萨莉亚",
        "烤鸭", "烧鸭", "卤鸭", "鸭肉", "可乐", "水溶", "c100",
    ],
    "keywordRules:日用": [
        "鸡蛋", "山姆", "山姆会员", "永辉", "永辉超市", "大润发", "钱大妈",
        "托育费", "幼儿园学费",
    ],
    "keywordRules:交通": [
        "花小猪", "洗车", "汽车保养", "车辆保养", "保养车", "ETC", "etc",
        "充电桩", "电车充电", "汽车充电", "补能",
    ],
    "keywordRules:健康": [
        "洗牙", "配镜", "验光", "医美", "光子嫩肤",
    ],
    "keywordRules:居家": [
        "保洁", "家政", "钟点工", "开荒保洁", "网上国网", "国网", "暖气费", "取暖费",
        "供暖费", "采暖费", "热力费", "上门保洁", "擦玻璃", "搬家",
    ],
    "keywordRules:娱乐": [
        "B站会员", "哔哩哔哩会员", "爱奇艺会员", "网易云会员", "网易云音乐会员",
        "腾讯视频会员", "优酷会员", "QQ音乐会员", "百度网盘会员",
        "网吧", "网咖", "直播打赏",
    ],
    "keywordRules:住宿": [
        "电竞酒店",
    ],
    "keywordRules:购物": [
        "充电器", "数据线", "充电宝", "谷子", "潮玩", "吧唧", "亚克力", "盲盒", "泡泡玛特", "痛包",
        "Office 365", "Microsoft 365", "Creative Cloud", "Notion订阅", "POP MART", "同人本", "乙游周边",
    ],
    "keywordRules:人情": [
        "白事", "白事随礼", "奠仪", "帛金",
    ],
    "keywordRules:其他": [
        "驾校", "驾考", "彩票", "刮刮乐",
    ],
    "ocrKeywordRules:餐饮": [
        "海底捞", "老乡鸡", "塔斯汀", "库迪", "库迪咖啡", "绝味", "袁记云饺", "萨莉亚",
        "烤鸭",
    ],
    "ocrKeywordRules:日用": [
        "山姆", "山姆会员", "永辉", "永辉超市", "大润发", "钱大妈",
    ],
    "ocrKeywordRules:交通": [
        "花小猪", "洗车", "汽车保养", "车辆保养", "保养车", "ETC", "etc", "充电桩", "电车充电",
    ],
    "ocrKeywordRules:居家": [
        "网上国网", "国网", "暖气费", "取暖费", "供暖费", "采暖费", "家政", "保洁", "搬家",
    ],
    "ocrKeywordRules:购物": [
        "谷子", "潮玩", "吧唧", "亚克力", "盲盒", "泡泡玛特", "痛包",
        "Office 365", "Microsoft 365", "Creative Cloud", "Notion订阅", "POP MART", "同人本", "乙游周边",
    ],
    "ocrKeywordRules:娱乐": [
        "腾讯视频会员", "优酷会员", "QQ音乐会员", "百度网盘会员",
        "网吧", "直播打赏",
    ],
    "ocrKeywordRules:住宿": [
        "电竞酒店",
    ],
    "ocrKeywordRules:其他": [
        "驾校", "彩票", "刮刮乐",
    ],
    "emotionKeywordRules:convenience": [
        "茶叶蛋", "饭团", "关东煮", "便当", "三明治",
    ],
    "emotionKeywordRules:drink": [
        "可乐", "雪碧", "汽水", "水溶", "c100", "维C",
    ],
    "emotionKeywordRules:meal": [
        "烤鸭", "烧鸭", "卤鸭", "鸭肉",
    ],
}

EXPECTED_BRANDS = [
    "haidilao", "laoxiangji", "tastien", "cotti", "juewei", "yuanjiyunjiao",
    "saizeriya", "samsclub", "yonghui", "rtmart", "qiandama", "huaxiaozhu",
    "sgcc_online",
]

EXPECTED_SWIFT_SNIPPETS = {
    "semantic_fallback": [
        "茶叶蛋", "饭团", "关东煮", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴",
        "烤鸭", "烧鸭", "卤鸭", "鸭肉", "可乐", "水溶", "c100",
        "山姆", "永辉", "大润发", "钱大妈", "花小猪", "洗车", "汽车保养",
        "配镜", "验光", "洗牙", "网上国网", "暖气费", "取暖费", "B站会员",
        "供暖费", "热力费", "腾讯视频会员", "充电器", "Office 365", "谷子", "潮玩", "泡泡玛特", "POP MART", "搬家",
        "托育费", "直播打赏", "网吧", "电竞酒店", "医美", "白事随礼", "驾校", "彩票",
    ],
    "life_scene": [
        "茶叶蛋", "饭团", "关东煮", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴",
        "烤鸭", "烧鸭", "卤鸭", "鸭肉", "可乐", "水溶", "c100",
        "山姆", "永辉", "大润发", "钱大妈", "花小猪", "洗车", "汽车保养",
        "配镜", "验光", "洗牙", "网上国网", "暖气费", "取暖费", "B站会员",
        "供暖费", "热力费", "腾讯视频会员", "充电器", "Office 365", "谷子", "潮玩", "泡泡玛特", "POP MART", "搬家",
        "托育费", "直播打赏", "网吧", "电竞酒店", "医美", "白事随礼", "驾校", "彩票", "telecomBill", "手机话费",
    ],
    "life_mark": [
        "茶叶蛋", "饭团", "关东煮", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴",
        "山姆", "永辉", "大润发", "钱大妈", "洗车", "汽车保养",
        "配镜", "验光", "洗牙", "网上国网", "暖气费", "取暖费", "B站会员",
        "供暖费", "热力费", "腾讯视频会员", "Office 365", "谷子", "潮玩", "泡泡玛特", "POP MART", "搬家",
        "托育费", "直播打赏", "网吧", "医美", "白事随礼", "驾校", "telecom_bill", "手机话费",
    ],
    "record_view": [
        "茶叶蛋", "饭团", "关东煮", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴",
        "山姆", "永辉", "大润发", "钱大妈", "花小猪", "洗车", "汽车保养",
        "配镜", "验光", "洗牙", "b站会员",
        "腾讯视频会员", "供暖费", "上门保洁", "充电桩", "office 365", "谷子", "泡泡玛特", "pop mart", "搬家",
        "托育费", "直播打赏", "网吧", "电竞酒店", "医美", "白事随礼", "驾校", "彩票",
    ],
    "memory_context": [
        "充电桩", "电车充电", "汽车充电", "补能",
    ],
    "home_view": [
        "haidilao", "laoxiangji", "tastien", "cotti", "juewei", "yuanjiyunjiao",
        "saizeriya", "samsclub", "yonghui", "rtmart", "qiandama", "huaxiaozhu",
        "sgcc_online", "playbackContainsDrinkCue", "playbackContainsRoastDuckCue",
    ],
}

INTENTS_REQUIRING_KEYWORD_MATCH = [
    "commute",
    "daily_supply",
    "everyday_meal",
    "telecom_bill",
    "household_service",
    "car_care",
    "digital_subscription",
    "leisure",
]

DAILY_SUPPLY_EXCLUSION_IDS = [
    "fitness",
    "home_utilities",
    "telecom_bill",
    "household_service",
    "digital_subscription",
    "baby_supply",
    "medical_care",
    "social_care",
    "groceries",
    "interest_gear",
    "learning_growth",
    "pet_supply",
]

LEISURE_EXCLUSION_IDS = [
    "fitness",
    "digital_subscription",
    "social_care",
    "movie_ticket",
    "travel",
    "interest_gear",
    "learning_growth",
]

SCENE_PACK_BLOCKED_TERMS = [
    "房租", "押金", "租房", "水电", "燃气", "物业", "宽带", "电影", "健身",
]

BLOCKED_COPY_SNIPPETS = [
    "这一袋" + "很方便",
    "中午这顿饭" + "先吃上了。",
    "今天的一笔" + "，记下来了。",
    "小" + "停顿",
    "硬" + "撑",
    "被解释" + "成",
    "路上" + "匆忙",
]

BROAD_QUOTED_KEYWORD_LIMITS = {
    "饭": 10,
    "吃": 6,
    "餐": 7,
    "面": 5,
    "奶": 0,
    "a2": 0,
    "保养": 0,
    "鸡": 0,
    "会员": 0,
    "Office": 0,
    "Adobe": 0,
    "Notion": 0,
    "订阅": 0,
    "周边": 0,
    "漫展": 0,
    "学费": 0,
    "打赏": 0,
    "脱毛": 0,
}

SEMANTIC_TIE_PRIORITY = {
    "交通": 0,
    "餐饮": 1,
    "购物": 2,
    "日用": 3,
    "健康": 4,
    "居家": 5,
    "住宿": 6,
    "人情": 7,
    "娱乐": 8,
    "其他": 9,
}

OCR_TIE_PRIORITY = {
    "餐饮": 0,
    "交通": 1,
    "购物": 2,
    "日用": 3,
    "娱乐": 4,
    "住宿": 5,
    "健康": 6,
    "居家": 7,
    "人情": 8,
    "其他": 9,
}


def read_text(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def assert_no_dead_semantic_source(failures: list[str]) -> None:
    dead_path = ROOT / "NativeDemoApp/Services/RecordSemanticLexicon.swift"
    if dead_path.exists():
        failures.append(
            "RecordSemanticLexicon has a duplicate source at "
            "NativeDemoApp/Services/RecordSemanticLexicon.swift; use NativeDemoApp/Models/HomeItem.swift"
        )


def collect_keywords(payload: dict, section: str, key: str, value: str) -> set[str]:
    keywords: set[str] = set()
    for rule in payload.get(section, []):
        if not isinstance(rule, dict) or rule.get(key) != value:
            continue
        for keyword in rule.get("keywords", []):
            if isinstance(keyword, str):
                keywords.add(keyword)
    return keywords


def require_contains(failures: list[str], label: str, actual: set[str], expected: list[str]) -> None:
    missing = [keyword for keyword in expected if keyword not in actual]
    if missing:
        failures.append(f"{label}: missing {', '.join(missing)}")


def extract_life_mark_block(text: str, intent_id: str) -> str:
    marker = f'id: "{intent_id}"'
    marker_index = text.find(marker)
    if marker_index < 0:
        return ""
    start = text.rfind("LifeMarkDefinition(", 0, marker_index)
    if start < 0:
        return ""
    next_start = text.find("LifeMarkDefinition(", marker_index + len(marker))
    if next_start < 0:
        next_start = text.find("\n    ]", marker_index)
    return text[start:next_start]


def extract_swift_string_set(text: str, name: str) -> set[str]:
    marker = f"let {name}: Set<String>"
    marker_index = text.find(marker)
    if marker_index < 0:
        return set()
    start = text.find("[", marker_index)
    end = text.find("]", start)
    if start < 0 or end < 0:
        return set()
    return set(re.findall(r'"([^"]+)"', text[start:end]))


def scan_json(failures: list[str]) -> None:
    payload = json.loads(LEXICON_PATH.read_text(encoding="utf-8"))
    for label, expected in EXPECTED_JSON_KEYWORDS.items():
        section, value = label.split(":", 1)
        key = "id" if section == "emotionKeywordRules" else "category"
        actual = collect_keywords(payload, section, key, value)
        require_contains(failures, label, actual, expected)


def scan_swift_presence(failures: list[str]) -> dict[str, str]:
    texts = {name: read_text(path) for name, path in SWIFT_FILES.items()}

    brand_text = texts["brands"]
    for brand_id in EXPECTED_BRANDS:
        if f'brand("{brand_id}"' not in brand_text:
            failures.append(f"MerchantBrandCatalog: missing brand id {brand_id}")
    if re.search(r'brand\("yuanjiyunjiao"[\s\S]*?\["[^"]*袁记[^云]', brand_text):
        failures.append("MerchantBrandCatalog: yuanjiyunjiao alias must stay specific, not bare 袁记")

    for name, expected in EXPECTED_SWIFT_SNIPPETS.items():
        text = texts[name]
        haystack = text if name != "record_view" else text.lower()
        missing = [snippet for snippet in expected if snippet not in haystack]
        if missing:
            failures.append(f"{SWIFT_FILES[name]}: missing snippets {', '.join(missing)}")

    for name in ["semantic_fallback"]:
        if "ocrKeywordRules:" not in texts[name]:
            failures.append(f"{SWIFT_FILES[name]}: fallback missing ocrKeywordRules")

    if '"充电"' in texts["memory_context"]:
        failures.append(f"{SWIFT_FILES['memory_context']}: memory charging cue must not use broad \"充电\"")
    if '"充电"' in texts["insight_web_view"]:
        failures.append(f"{SWIFT_FILES['insight_web_view']}: title keyword candidates must not use broad \"充电\"")

    life_mark_text = texts["life_mark"]
    for intent_id in INTENTS_REQUIRING_KEYWORD_MATCH:
        block = extract_life_mark_block(life_mark_text, intent_id)
        if not block:
            failures.append(f"LifeMarkService: missing intent {intent_id}")
            continue
        if "requiresKeywordMatch: true" not in block:
            failures.append(f"LifeMarkService: {intent_id} must require keyword match")

    return texts


def scan_blocked_copy(failures: list[str], texts: dict[str, str]) -> None:
    checked = {
        "RecordSceneLexicon.json": LEXICON_PATH.read_text(encoding="utf-8"),
        "RecordSceneLexicon.regression.json": REGRESSION_CASES_PATH.read_text(encoding="utf-8"),
        **{SWIFT_FILES[name]: text for name, text in texts.items()},
    }
    for path, text in checked.items():
        for snippet in BLOCKED_COPY_SNIPPETS:
            if snippet in text:
                failures.append(f"{path}: blocked copy snippet `{snippet}`")


def scan_scene_pack_notes(failures: list[str], text: str) -> None:
    for line_number, line in enumerate(text.splitlines(), start=1):
        if "ScenePackTier(" not in line:
            continue
        for term in SCENE_PACK_BLOCKED_TERMS:
            if term in line:
                failures.append(f"ScenePackCopyPool.swift:{line_number}: tier note contains LifeMark term {term}")


def scan_life_mark_boundaries(failures: list[str], text: str) -> None:
    home_utilities = extract_life_mark_block(text, "home_utilities")
    if '"话费"' in home_utilities or '"手机话费"' in home_utilities:
        failures.append("LifeMarkService: home_utilities must not absorb telecom bill keywords")

    commute = extract_life_mark_block(text, "commute")
    if '"花小猪"' in commute:
        failures.append("LifeMarkService: commute must not treat ride-hailing brand alone as high-confidence commute")

    daily_exclusions = extract_swift_string_set(text, "broadDailySupplySpecificDefinitionIDs")
    missing_daily = [intent_id for intent_id in DAILY_SUPPLY_EXCLUSION_IDS if intent_id not in daily_exclusions]
    if missing_daily:
        failures.append(
            "LifeMarkService: daily_supply broad match missing exclusions "
            + ", ".join(missing_daily)
        )

    leisure_exclusions = extract_swift_string_set(text, "broadLeisureSpecificDefinitionIDs")
    missing_leisure = [intent_id for intent_id in LEISURE_EXCLUSION_IDS if intent_id not in leisure_exclusions]
    if missing_leisure:
        failures.append(
            "LifeMarkService: leisure broad match missing exclusions "
            + ", ".join(missing_leisure)
        )


def scan_broad_keywords(failures: list[str], texts: dict[str, str]) -> None:
    checked = {
        "RecordSceneLexicon.json": LEXICON_PATH.read_text(encoding="utf-8"),
        **{SWIFT_FILES[name]: text for name, text in texts.items()},
    }
    totals = {keyword: 0 for keyword in BROAD_QUOTED_KEYWORD_LIMITS}
    for text in checked.values():
        for keyword in totals:
            totals[keyword] += text.count(f'"{keyword}"')
    for keyword, limit in BROAD_QUOTED_KEYWORD_LIMITS.items():
        if totals[keyword] > limit:
            failures.append(
                f"broad quoted keyword \"{keyword}\" count increased: {totals[keyword]} > {limit}"
            )


def score_text(payload: dict, text: str, sections: list[str], tie_priority: dict[str, int]) -> str | None:
    normalized = text.strip().lower()
    if not normalized:
        return None
    scores: dict[str, float] = {}
    for section in sections:
        for rule in payload.get(section, []):
            category = rule.get("category")
            keywords = rule.get("keywords", [])
            if not isinstance(category, str) or not isinstance(keywords, list):
                continue
            if any(isinstance(keyword, str) and keyword.lower() in normalized for keyword in keywords):
                scores[category] = scores.get(category, 0) + float(rule.get("score", 0))
    if not scores:
        return None
    return sorted(
        scores.items(),
        key=lambda entry: (-entry[1], tie_priority.get(entry[0], 99)),
    )[0][0]


def should_score_regression_case(case: dict) -> bool:
    if not isinstance(case, dict):
        return False
    if "expectedCategory" not in case:
        return False
    if case.get("history") or case.get("selectedCategory") or case.get("categoryLockedByUser"):
        return False
    return bool(case.get("inputTitle") or case.get("rawText"))


def scan_regression_cases(failures: list[str], payload: dict) -> None:
    cases_payload = json.loads(REGRESSION_CASES_PATH.read_text(encoding="utf-8"))
    for case in cases_payload.get("cases", []):
        if not should_score_regression_case(case):
            continue
        case_id = case.get("id", "<missing-id>")
        mode = case.get("mode")
        text = case.get("rawText") if mode == "ocr" else case.get("inputTitle")
        sections = ["keywordRules", "ocrKeywordRules"] if mode == "ocr" else ["keywordRules"]
        tie_priority = OCR_TIE_PRIORITY if mode == "ocr" else SEMANTIC_TIE_PRIORITY
        actual = score_text(payload, str(text or ""), sections, tie_priority)
        expected = case.get("expectedCategory")
        if actual != expected:
            failures.append(f"RecordSceneLexicon.regression.json:{case_id}: expected {expected}, got {actual}")


def main() -> int:
    failures: list[str] = []
    payload = json.loads(LEXICON_PATH.read_text(encoding="utf-8"))
    assert_no_dead_semantic_source(failures)
    scan_json(failures)
    scan_regression_cases(failures, payload)
    texts = scan_swift_presence(failures)
    scan_blocked_copy(failures, texts)
    scan_scene_pack_notes(failures, texts["scene_pack"])
    scan_life_mark_boundaries(failures, texts["life_mark"])
    scan_broad_keywords(failures, texts)

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1

    print("life_semantic_regression: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
