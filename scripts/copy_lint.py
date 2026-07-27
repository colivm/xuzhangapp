#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

DEFAULT_SWIFT_ROOTS = [
    "NativeDemoApp",
]

DEFAULT_LEXICONS = [
    "NativeDemoApp/Resources/RecordSceneLexicon.json",
]

BLOCKED_TERMS = [
    "账单字段",
    "账单字段云端开",
    "联网整理开",
    "联网梳理已开",
    "仅本地保存",
    "这一袋" + "很方便",
    "中午这顿饭" + "先吃上了。",
    "今天的一笔" + "，记下来了。",
    "小" + "停顿",
    "硬" + "撑",
    "被解释" + "成",
    "路上" + "匆忙",
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
    "被按下暂停",
    "生活自己说出来",
    "生活道具",
    "冷冰冰",
    "那几刻",
    "一下子有了热度",
    "生活资产",
    "生活切片",
    "小标记",
    "硬总结",
    "被照顾到",
    "轮廓就更清楚",
    "像不像你的",
    "读懂我",
    "生活意义",
    "把身体放回",
    "给生活补库存",
    "压力找出口",
    "关系在发生",
    "真正的主题",
    "孤零零的金额",
    "不只是消费",
    "不该只剩金额",
    "更像这段时间",
    "值得被看见",
    "紧绷的日子",
    "生活在往",
    "金额只是痕迹",
    "被留下来",
    "被留下来了",
    "生活自己",
    "撑住这一周",
    "最有画面",
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

CONTEXTUAL_TERMS = [
    {
        "name": "recovery_or_effort_tone",
        "terms": ["辛苦", "缓一缓", "费心"],
        "evidence": [
            "通勤", "下班", "晚归", "到家", "路上", "雨", "雪", "热天", "冷天",
            "就医", "检查", "问诊", "医院", "身体", "护理", "恢复", "用药", "药",
        ],
    },
    {
        "name": "picture_tone",
        "terms": ["有画面"],
        "evidence": [
            "朋友", "聚餐", "见面", "相聚", "旅行", "异地", "外地", "雨", "晚归",
            "爱好", "兴趣", "装备", "具体物件", "备注", "voice", "Voice", "scene", "Scene",
        ],
    },
    {
        "name": "first_time_memory_tone",
        "terms": ["第一次"],
        "evidence": [
            "target == 1", ".milestone", "milestone", "里程碑", "首次", "第一笔",
            "第一条", "第一单", "第1", "买", "露营", "渔具", "骑行", "摄影",
            "乐器", "健身", "恢复", "宝宝", "毛孩子", "奶粉", "尿不湿",
            "text.contains", "trimmed.contains", "emotion.contains", "target.map", "target =", "displayLabel",
            "雨天通勤", "第 10 次", "连续记录", "异地城市",
        ],
    },
]

LEGAL_CATEGORIES = {
    "餐饮",
    "交通",
    "购物",
    "日用",
    "娱乐",
    "住宿",
    "健康",
    "居家",
    "人情",
    "其他",
}

SANITIZER_FUNC_NAMES = [
    "sanitizeLifeNote",
    "sanitizeBrandNote",
]

UNICODE_REPLACEMENT_CHARACTER = "\ufffd"


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
    parser.add_argument(
        "--lexicon",
        action="append",
        default=[],
        help="Validate a RecordSceneLexicon JSON file in addition to copy-bearing files.",
    )
    return parser.parse_args()


def expand_paths(raw_paths: list[str]) -> list[Path]:
    if not raw_paths:
        files: list[Path] = []
        for root in DEFAULT_SWIFT_ROOTS:
            base = ROOT / root
            if base.is_dir():
                files.extend(sorted(p for p in base.rglob("*.swift") if p.is_file()))
        return files

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
    for start_index, line in enumerate(lines):
        stripped = line.strip()
        if stripped not in {"BLOCKED_TERMS = [", "SOFT_TERMS = ["}:
            continue
        ignored.add(start_index)
        for index in range(start_index + 1, len(lines)):
            ignored.add(index)
            if lines[index].strip() == "]":
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
        if UNICODE_REPLACEMENT_CHARACTER in line or any(
            0x80 <= ord(character) <= 0x9F for character in line
        ):
            failures.append(f"{location}: probable mojibake or replacement character")
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
        for rule in CONTEXTUAL_TERMS:
            for term in rule["terms"]:
                if term in line and not any(marker in line for marker in rule["evidence"]):
                    failures.append(
                        f"{location}: contextual term `{term}` lacks evidence for {rule['name']}"
                    )

    return failures, warnings


def validate_keyword_list(
    payload: dict,
    section: str,
    failures: list[str],
    *,
    requires_score: bool = True,
    requires_id: bool = False,
) -> None:
    rules = payload.get(section)
    if not isinstance(rules, list) or not rules:
        failures.append(f"{section}: expected non-empty rule list")
        return

    for index, rule in enumerate(rules):
        prefix = f"{section}[{index}]"
        if not isinstance(rule, dict):
            failures.append(f"{prefix}: expected object")
            continue

        category = rule.get("category")
        if category not in LEGAL_CATEGORIES:
            failures.append(f"{prefix}.category: illegal category `{category}`")

        if requires_id:
            rule_id = rule.get("id")
            if not isinstance(rule_id, str) or not rule_id.strip():
                failures.append(f"{prefix}.id: expected non-empty string")

        if requires_score and not isinstance(rule.get("score"), (int, float)):
            failures.append(f"{prefix}.score: expected number")

        keywords = rule.get("keywords")
        if not isinstance(keywords, list) or not keywords:
            failures.append(f"{prefix}.keywords: expected non-empty list")
            continue
        for keyword_index, keyword in enumerate(keywords):
            if not isinstance(keyword, str) or not keyword.strip():
                failures.append(f"{prefix}.keywords[{keyword_index}]: expected non-empty string")


def scan_blocked_terms(value: object, location: str, failures: list[str]) -> None:
    if isinstance(value, str):
        for term in BLOCKED_TERMS:
            if term in value:
                failures.append(f"{location}: blocked term `{term}`")
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            scan_blocked_terms(item, f"{location}[{index}]", failures)
        return
    if isinstance(value, dict):
        for key, item in value.items():
            scan_blocked_terms(item, f"{location}.{key}", failures)


def validate_lexicon(path: Path) -> list[str]:
    failures: list[str] = []
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except UnicodeDecodeError:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        return [f"{display_path(path)}:{exc.lineno}: invalid JSON: {exc.msg}"]

    if not isinstance(payload, dict):
        return [f"{display_path(path)}: expected top-level object"]

    validate_keyword_list(payload, "keywordRules", failures)
    validate_keyword_list(payload, "ocrKeywordRules", failures)
    validate_keyword_list(payload, "emotionKeywordRules", failures, requires_score=False, requires_id=True)

    combo_rules = payload.get("comboRules", [])
    if not isinstance(combo_rules, list):
        failures.append("comboRules: expected list")
    for index, rule in enumerate(combo_rules if isinstance(combo_rules, list) else []):
        prefix = f"comboRules[{index}]"
        if not isinstance(rule, dict):
            failures.append(f"{prefix}: expected object")
            continue
        keywords = rule.get("keywords")
        if not isinstance(keywords, list) or not keywords:
            failures.append(f"{prefix}.keywords: expected non-empty list")
        scores = rule.get("scores")
        if not isinstance(scores, dict) or not scores:
            failures.append(f"{prefix}.scores: expected non-empty object")
            continue
        for category, score in scores.items():
            if category not in LEGAL_CATEGORIES:
                failures.append(f"{prefix}.scores: illegal category `{category}`")
            if not isinstance(score, (int, float)):
                failures.append(f"{prefix}.scores.{category}: expected number")

    scan_blocked_terms(payload, display_path(path), failures)
    return [f"{display_path(path)}: {failure}" for failure in failures]


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

    lexicons = args.lexicon or ([] if args.paths else DEFAULT_LEXICONS)
    for raw_lexicon in lexicons:
        lexicon_path = Path(raw_lexicon)
        if not lexicon_path.is_absolute():
            lexicon_path = ROOT / lexicon_path
        if not lexicon_path.is_file():
            all_failures.append(f"{display_path(lexicon_path)}: file not found")
            continue
        all_failures.extend(validate_lexicon(lexicon_path))

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
