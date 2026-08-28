#!/usr/bin/env python3
"""Validate the public site and legal pages against confirmed compliance facts."""

from __future__ import annotations

from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlparse


ROOT = Path(__file__).resolve().parents[1]
PUBLIC_ROOT = ROOT / "site"
PAGES = (
    ROOT / "site" / "index.html",
    ROOT / "legal" / "privacy.html",
    ROOT / "legal" / "terms.html",
)

REQUIRED_BY_PAGE = {
    "index.html": (
        "王义磊（个人）",
        "yilei wang",
        "江苏省南京市浦口区",
        "Apple WeatherKit",
        "DeepSeek",
        "苏ICP备2026035096号-1",
    ),
    "privacy.html": (
        "版本：v1.0",
        "个人信息处理者与运营者",
        "王义磊（个人）",
        "江苏省南京市浦口区",
        "yilei wang",
        "Apple WeatherKit",
        "DeepSeek",
        "阿里云",
        "Cloudflare Email Routing",
        "不做人脸身份识别",
        "照片、像素、人脸框、色板",
        "15 个工作日",
        "support@xuzhang.app",
        "hello@xuzhang.app",
        "苏ICP备2026035096号-1",
    ),
    "terms.html": (
        "版本：v1.0",
        "王义磊（个人）",
        "江苏省南京市浦口区",
        "yilei wang",
        "Apple WeatherKit",
        "DeepSeek",
        "以当前 App 与 App Store 展示为准",
        "support@xuzhang.app",
        "hello@xuzhang.app",
        "苏ICP备2026035096号-1",
    ),
}

FORBIDDEN = (
    "Open-Meteo",
    "智谱",
    "账单字段",
    "看看花",
    "生活切片",
    "周切片",
    "小 AI 说",
    "苏公网安备",
    "每自然周 1 次",
    "终生 3 次月章",
    "继续使用本 App，即表示",
)


class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.ids: list[str] = []
        self.references: list[tuple[str, str]] = []
        self.html_count = 0
        self.head_count = 0
        self.body_count = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if tag == "html":
            self.html_count += 1
        elif tag == "head":
            self.head_count += 1
        elif tag == "body":
            self.body_count += 1
        if identifier := values.get("id"):
            self.ids.append(identifier)
        for attribute in ("href", "src"):
            if reference := values.get(attribute):
                self.references.append((attribute, reference))


def local_target(page: Path, reference: str) -> Path | None:
    parsed = urlparse(reference)
    if parsed.scheme or parsed.netloc or reference.startswith("//"):
        assert parsed.scheme in {"https", "mailto"}, f"unsupported URL scheme in {page}: {reference}"
        return None
    path_text = unquote(parsed.path)
    if not path_text:
        return None
    if path_text == "/":
        return PUBLIC_ROOT / "index.html"
    if path_text.startswith("/legal/"):
        return ROOT / path_text.lstrip("/")
    if path_text.startswith("/"):
        return PUBLIC_ROOT / path_text.lstrip("/")
    return page.parent / path_text


def validate_page(path: Path) -> None:
    raw = path.read_text(encoding="utf-8")
    parser = PageParser()
    parser.feed(raw)
    parser.close()

    assert (parser.html_count, parser.head_count, parser.body_count) == (1, 1, 1), path
    assert len(parser.ids) == len(set(parser.ids)), f"duplicate id in {path}"
    for required in REQUIRED_BY_PAGE[path.name]:
        assert required in raw, f"missing {required!r} in {path}"
    for forbidden in FORBIDDEN:
        assert forbidden not in raw, f"stale or unsupported claim {forbidden!r} in {path}"

    for attribute, reference in parser.references:
        target = local_target(path, reference)
        if target is not None:
            assert target.is_file(), f"broken local {attribute} in {path}: {reference} -> {target}"
        fragment = urlparse(reference).fragment
        if fragment and not urlparse(reference).path:
            assert fragment in parser.ids, f"broken fragment in {path}: #{fragment}"

    print(f"compliance page OK: {path.relative_to(ROOT)}")


def main() -> None:
    for page in PAGES:
        validate_page(page)
    print("compliance_html_check: OK")


if __name__ == "__main__":
    main()
