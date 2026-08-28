#!/usr/bin/env python3
"""Validate the checked-in Nginx security policy and, optionally, production."""

from __future__ import annotations

import argparse
import http.client
import json
import ssl
from pathlib import Path
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[1]
SITE_CONFIG = ROOT / "ops/nginx/xuzhangapp.com.conf"
API_CONFIG = ROOT / "ops/nginx/api.xuzhangapp.com.conf"

COMMON_HEADERS = {
    "strict-transport-security",
    "content-security-policy",
    "x-content-type-options",
    "x-frame-options",
    "referrer-policy",
    "permissions-policy",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"security_headers_check: {message}")


def validate_config() -> None:
    site = SITE_CONFIG.read_text(encoding="utf-8")
    api = API_CONFIG.read_text(encoding="utf-8")

    for label, text in (("site", site), ("api", api)):
        require("max-age=31536000; includeSubDomains" in text, f"{label} HSTS is missing")
        require('add_header X-Content-Type-Options "nosniff" always;' in text, f"{label} nosniff is missing")
        require('add_header X-Frame-Options "DENY" always;' in text, f"{label} frame denial is missing")
        require("add_header Permissions-Policy" in text, f"{label} permissions policy is missing")
        require("server_tokens off;" in text, f"{label} exposes the Nginx version")
        require("Access-Control-Allow-Origin" not in text, f"{label} must not override application CORS")
        require("ssl_certificate /etc/letsencrypt/live/" in text, f"{label} must keep Let's Encrypt paths")

    require("server_name xuzhangapp.com www.xuzhangapp.com;" in site, "site server names drifted")
    require("root /opt/xuzhang/xuzhangapp/site;" in site, "site root drifted")
    require("alias /opt/xuzhang/xuzhangapp/legal/;" in site, "legal alias drifted")
    require("default-src 'self'" in site, "site CSP must default to same-origin")
    require("script-src 'self'" in site, "site scripts must stay same-origin")
    require("script-src-attr 'unsafe-inline'" in site, "existing image fallback handlers need the narrow attribute exception")
    require("style-src 'self' 'unsafe-inline'" in site, "existing inline presentation variables need the style exception")
    require("'unsafe-eval'" not in site, "site CSP must not allow unsafe-eval")
    require("object-src 'none'" in site and "frame-ancestors 'none'" in site, "site active embedding must be denied")

    require("server_name api.xuzhangapp.com;" in api, "API server name drifted")
    require("proxy_pass http://127.0.0.1:8790;" in api, "API upstream drifted")
    require("proxy_hide_header X-Powered-By;" in api, "API must hide the Express identity header")
    require("proxy_hide_header Content-Security-Policy;" in api, "Nginx must own the API CSP")
    require("proxy_hide_header X-Content-Type-Options;" in api, "Nginx must own API MIME protection")
    require("default-src 'none'" in api, "API CSP must deny browser resources")
    require("ssl_protocols TLSv1.2 TLSv1.3;" in api, "API TLS protocol boundary drifted")
    print("security_headers_config: OK")


def request(url: str, method: str = "HEAD", headers: dict[str, str] | None = None) -> tuple[int, dict[str, str], bytes]:
    parsed = urlsplit(url)
    require(parsed.scheme in {"http", "https"}, f"unsupported URL scheme: {url}")
    connection_type = http.client.HTTPSConnection if parsed.scheme == "https" else http.client.HTTPConnection
    kwargs = {"timeout": 15}
    if parsed.scheme == "https":
        kwargs["context"] = ssl.create_default_context()
    connection = connection_type(parsed.hostname, parsed.port, **kwargs)
    path = parsed.path or "/"
    if parsed.query:
        path += f"?{parsed.query}"
    connection.request(method, path, headers=headers or {})
    response = connection.getresponse()
    body = response.read()
    header_pairs = response.getheaders()
    response_headers = {key.lower(): value for key, value in header_pairs}
    for security_header in COMMON_HEADERS | {"x-powered-by"}:
        count = sum(key.lower() == security_header for key, _ in header_pairs)
        require(count <= 1, f"duplicate live header {security_header}: {url}")
    connection.close()
    return response.status, response_headers, body


def validate_security_headers(label: str, headers: dict[str, str], csp_fragment: str) -> None:
    missing = sorted(COMMON_HEADERS - headers.keys())
    require(not missing, f"{label} missing live headers: {', '.join(missing)}")
    require(headers["strict-transport-security"] == "max-age=31536000; includeSubDomains", f"{label} HSTS drifted")
    require(headers["x-content-type-options"] == "nosniff", f"{label} nosniff drifted")
    require(headers["x-frame-options"] == "DENY", f"{label} frame policy drifted")
    require(csp_fragment in headers["content-security-policy"], f"{label} CSP drifted")
    require("/" not in headers.get("server", ""), f"{label} exposes a server version")


def validate_live() -> None:
    for path in ("/", "/legal/privacy.html", "/legal/terms.html"):
        status, headers, _ = request(f"https://xuzhangapp.com{path}")
        require(status == 200, f"site {path} returned {status}")
        require(headers.get("content-type", "").startswith("text/html"), f"site {path} content type drifted")
        validate_security_headers(f"site {path}", headers, "default-src 'self'")

    status, headers, body = request("https://api.xuzhangapp.com/health", method="GET")
    require(status == 200, f"API health returned {status}")
    require(json.loads(body)["ok"] is True, "API health body drifted")
    validate_security_headers("API health", headers, "default-src 'none'")
    require("x-powered-by" not in headers, "API still exposes X-Powered-By")

    status, headers, body = request("https://api.xuzhangapp.com/v1/account/me", method="GET")
    require(status == 401, f"protected API route returned {status} instead of 401")
    require(json.loads(body) == {"ok": False, "error": "UNAUTHORIZED"}, "protected API body drifted")
    validate_security_headers("API 401", headers, "default-src 'none'")
    require("x-powered-by" not in headers, "API 401 still exposes X-Powered-By")

    status, headers, _ = request("https://api.xuzhangapp.com/not-found-security-check", method="GET")
    require(status == 404, f"missing API route returned {status} instead of 404")
    validate_security_headers("API 404", headers, "default-src 'none'")
    require("x-powered-by" not in headers, "API 404 still exposes X-Powered-By")

    status, headers, _ = request(
        "https://api.xuzhangapp.com/v1/account/me",
        method="OPTIONS",
        headers={"Origin": "https://xuzhangapp.com", "Access-Control-Request-Method": "GET"},
    )
    require(status == 204, f"API preflight returned {status}")
    require(headers.get("access-control-allow-origin") == "https://xuzhangapp.com", "API CORS behavior drifted")
    validate_security_headers("API preflight", headers, "default-src 'none'")

    for url in ("http://xuzhangapp.com/", "http://api.xuzhangapp.com/health"):
        status, headers, _ = request(url)
        require(status == 301, f"HTTP redirect returned {status}: {url}")
        require(headers.get("location", "").startswith("https://"), f"HTTP redirect is not HTTPS: {url}")

    print("security_headers_live: OK")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--live", action="store_true", help="also validate production over the public network")
    args = parser.parse_args()
    validate_config()
    if args.live:
        validate_live()


if __name__ == "__main__":
    main()
