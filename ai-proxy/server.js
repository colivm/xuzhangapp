const https = require("https");
const express = require("express");
const cors = require("cors");
require("dotenv").config();

const app = express();
app.use(cors());
app.use(express.json({ limit: "512kb" }));

const PORT = Number(process.env.PORT || 8787);
const ZHIPU_API_URL = "https://open.bigmodel.cn/api/paas/v4/chat/completions";
const ZHIPU_API_KEY = process.env.ZHIPU_API_KEY || "";
const APP_PROXY_TOKEN = process.env.APP_PROXY_TOKEN || "";
const MONTHLY_REQUEST_LIMIT = Number(process.env.MONTHLY_REQUEST_LIMIT || 5000);

let usage = {
  monthKey: monthIdentifier(),
  count: 0,
};

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    service: "ai-proxy",
    month: usage.monthKey,
    count: usage.count,
    limit: MONTHLY_REQUEST_LIMIT,
  });
});

app.post("/v1/insight/daily", async (req, res) => {
  try {
    if (!ZHIPU_API_KEY) {
      return res.status(500).json({ code: "CONFIG_ERROR", message: "missing ZHIPU_API_KEY" });
    }

    if (APP_PROXY_TOKEN) {
      const incomingToken = (req.headers["x-proxy-token"] || "").toString();
      if (!incomingToken || incomingToken !== APP_PROXY_TOKEN) {
        return res.status(401).json({ code: "UNAUTHORIZED", message: "invalid proxy token" });
      }
    }

    resetMonthlyUsageIfNeeded();
    if (usage.count >= MONTHLY_REQUEST_LIMIT) {
      return res.status(429).json({ code: "RATE_LIMIT", message: "monthly proxy limit reached" });
    }

    const model = (req.body?.model || "glm-4-flash").toString();
    const messages = req.body?.messages;
    const temperature = Number(req.body?.temperature ?? 0.6);
    if (!Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ code: "INVALID_ARGUMENT", message: "messages is required" });
    }

    const upstreamBody = JSON.stringify({
      model,
      messages,
      temperature,
    });

    const upstream = await postJSON(ZHIPU_API_URL, upstreamBody, {
      "Content-Type": "application/json",
      Authorization: `Bearer ${ZHIPU_API_KEY}`,
    });

    if (upstream.statusCode < 200 || upstream.statusCode >= 300) {
      return res.status(502).json({
        code: "UPSTREAM_ERROR",
        message: "zhipu request failed",
        upstreamStatus: upstream.statusCode,
      });
    }

    const parsed = safeJSONParse(upstream.body);
    const content = parsed?.choices?.[0]?.message?.content;
    const payload = normalizeInsightPayload(content);
    if (!payload) {
      return res.status(502).json({ code: "PARSE_ERROR", message: "invalid model output" });
    }

    usage.count += 1;
    return res.json(payload);
  } catch (error) {
    return res.status(500).json({
      code: "INTERNAL_ERROR",
      message: "proxy failed",
      detail: error instanceof Error ? error.message : "unknown",
    });
  }
});

app.listen(PORT, () => {
  console.log(`ai-proxy running on http://localhost:${PORT}`);
});

function postJSON(urlString, body, headers) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlString);
    const request = https.request(
      {
        protocol: url.protocol,
        hostname: url.hostname,
        path: url.pathname + url.search,
        method: "POST",
        headers: {
          ...headers,
          "Content-Length": Buffer.byteLength(body),
        },
        timeout: 20000,
      },
      (response) => {
        const chunks = [];
        response.on("data", (chunk) => chunks.push(chunk));
        response.on("end", () => {
          resolve({
            statusCode: response.statusCode || 500,
            body: Buffer.concat(chunks).toString("utf8"),
          });
        });
      }
    );

    request.on("timeout", () => {
      request.destroy(new Error("request timeout"));
    });
    request.on("error", reject);
    request.write(body);
    request.end();
  });
}

function safeJSONParse(text) {
  try {
    return JSON.parse(text);
  } catch (_error) {
    return null;
  }
}

function normalizeInsightPayload(content) {
  if (typeof content !== "string") {
    return null;
  }
  const trimmed = content
    .replace(/```json/g, "")
    .replace(/```/g, "")
    .trim();

  const object = safeJSONParse(trimmed);
  if (!object) return null;
  if (
    typeof object.summary !== "string" ||
    typeof object.action !== "string" ||
    typeof object.encourage !== "string"
  ) {
    return null;
  }

  return {
    summary: object.summary.trim(),
    action: object.action.trim(),
    encourage: object.encourage.trim(),
  };
}

function monthIdentifier() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  return `${year}-${month}`;
}

function resetMonthlyUsageIfNeeded() {
  const currentMonth = monthIdentifier();
  if (usage.monthKey !== currentMonth) {
    usage = { monthKey: currentMonth, count: 0 };
  }
}
