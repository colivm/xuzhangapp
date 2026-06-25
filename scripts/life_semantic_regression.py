#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LEXICON_PATH = ROOT / "NativeDemoApp/Resources/RecordSceneLexicon.json"

SWIFT_FILES = {
    "brands": "NativeDemoApp/Services/MerchantBrandCatalog.swift",
    "semantic_fallback": "NativeDemoApp/Services/RecordSemanticLexicon.swift",
    "life_scene": "NativeDemoApp/Services/LifeSceneSemanticService.swift",
    "life_mark": "NativeDemoApp/Services/LifeMarkService.swift",
    "home_item": "NativeDemoApp/Models/HomeItem.swift",
    "record_view": "NativeDemoApp/Views/RecordView.swift",
    "scene_pack": "NativeDemoApp/Services/ScenePackCopyPool.swift",
    "home_view": "NativeDemoApp/Views/HomeView.swift",
}

EXPECTED_JSON_KEYWORDS = {
    "keywordRules:餐饮": [
        "茶叶蛋", "饭团", "关东煮", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴",
        "海底捞", "老乡鸡", "塔斯汀", "库迪", "库迪咖啡", "绝味", "袁记云饺", "萨莉亚",
    ],
    "keywordRules:日用": [
        "鸡蛋", "山姆", "山姆会员", "永辉", "永辉超市", "大润发", "钱大妈",
    ],
    "keywordRules:交通": [
        "花小猪", "洗车", "汽车保养", "车辆保养", "保养车", "ETC", "etc",
    ],
    "keywordRules:健康": [
        "洗牙", "配镜", "验光",
    ],
    "keywordRules:居家": [
        "保洁", "家政", "钟点工", "开荒保洁", "网上国网", "国网", "暖气费", "取暖费",
    ],
    "keywordRules:娱乐": [
        "B站会员", "哔哩哔哩会员", "爱奇艺会员", "网易云会员", "网易云音乐会员",
    ],
    "ocrKeywordRules:餐饮": [
        "海底捞", "老乡鸡", "塔斯汀", "库迪", "库迪咖啡", "绝味", "袁记云饺", "萨莉亚",
    ],
    "ocrKeywordRules:日用": [
        "山姆", "山姆会员", "永辉", "永辉超市", "大润发", "钱大妈",
    ],
    "ocrKeywordRules:交通": [
        "花小猪", "洗车", "汽车保养", "车辆保养", "保养车", "ETC", "etc",
    ],
    "ocrKeywordRules:居家": [
        "网上国网", "国网", "暖气费", "取暖费",
    ],
    "emotionKeywordRules:convenience": [
        "茶叶蛋", "饭团", "关东煮", "便当", "三明治",
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
        "山姆", "永辉", "大润发", "钱大妈", "花小猪", "洗车", "汽车保养",
        "配镜", "验光", "洗牙", "网上国网", "暖气费", "取暖费", "B站会员",
    ],
    "home_item": [
        "茶叶蛋", "饭团", "关东煮", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴",
        "山姆", "永辉", "大润发", "钱大妈", "花小猪", "洗车", "汽车保养",
        "配镜", "验光", "洗牙", "网上国网", "暖气费", "取暖费", "B站会员",
    ],
    "life_scene": [
        "茶叶蛋", "饭团", "关东煮", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴",
        "山姆", "永辉", "大润发", "钱大妈", "花小猪", "洗车", "汽车保养",
        "配镜", "验光", "洗牙", "网上国网", "暖气费", "取暖费", "B站会员",
    ],
    "life_mark": [
        "茶叶蛋", "饭团", "关东煮", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴",
        "山姆", "永辉", "大润发", "钱大妈", "花小猪", "洗车", "汽车保养",
        "配镜", "验光", "洗牙", "网上国网", "暖气费", "取暖费", "B站会员",
    ],
    "record_view": [
        "茶叶蛋", "饭团", "关东煮", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴",
        "山姆", "永辉", "大润发", "钱大妈", "花小猪", "洗车", "汽车保养",
        "配镜", "验光", "洗牙", "b站会员",
    ],
    "home_view": [
        "haidilao", "laoxiangji", "tastien", "cotti", "juewei", "yuanjiyunjiao",
        "saizeriya", "samsclub", "yonghui", "rtmart", "qiandama", "huaxiaozhu",
        "sgcc_online",
    ],
}

INTENTS_REQUIRING_KEYWORD_MATCH = [
    "everyday_meal",
    "household_service",
    "car_care",
    "digital_subscription",
]

SCENE_PACK_BLOCKED_TERMS = [
    "房租", "押金", "租房", "水电", "燃气", "物业", "宽带", "电影", "健身",
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
    "会员": 6,
}


def read_text(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


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

    for name in ["semantic_fallback", "home_item"]:
        if "ocrKeywordRules:" not in texts[name]:
            failures.append(f"{SWIFT_FILES[name]}: fallback missing ocrKeywordRules")

    life_mark_text = texts["life_mark"]
    for intent_id in INTENTS_REQUIRING_KEYWORD_MATCH:
        block = extract_life_mark_block(life_mark_text, intent_id)
        if not block:
            failures.append(f"LifeMarkService: missing intent {intent_id}")
            continue
        if "requiresKeywordMatch: true" not in block:
            failures.append(f"LifeMarkService: {intent_id} must require keyword match")

    return texts


def scan_scene_pack_notes(failures: list[str], text: str) -> None:
    for line_number, line in enumerate(text.splitlines(), start=1):
        if "ScenePackTier(" not in line:
            continue
        for term in SCENE_PACK_BLOCKED_TERMS:
            if term in line:
                failures.append(f"ScenePackCopyPool.swift:{line_number}: tier note contains LifeMark term {term}")


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


def main() -> int:
    failures: list[str] = []
    scan_json(failures)
    texts = scan_swift_presence(failures)
    scan_scene_pack_notes(failures, texts["scene_pack"])
    scan_broad_keywords(failures, texts)

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1

    print("life_semantic_regression: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
