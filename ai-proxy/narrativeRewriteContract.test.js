process.env.NODE_ENV = "test";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildNarrativeRewriteMessages,
  normalizeNarrativeRewriteBatch,
  validateNarrativeFactPacks,
} = require("./narrativeRewriteContract");
const { normalizeInsightPayload } = require("./legacyInsightContract");
const { normalizedSupportedFeature } = require("./aiFeaturePolicy");

function dayPack() {
  return {
    scope: "day",
    periodKey: "2026-07-22",
    facts: [
      {
        id: "F1",
        role: "lead",
        kind: "rhythm",
        label: "记录节奏",
        statement: "今天有 3 笔记录。",
        evidenceCount: 3,
      },
      {
        id: "F2",
        role: "mark",
        kind: "stableMark",
        label: "咖啡饮品",
        statement: "生活线索 · 咖啡饮品",
        evidenceCount: 2,
      },
    ],
  };
}

function monthPack() {
  return {
    scope: "month",
    periodKey: "2026-07",
    facts: [
      {
        id: "F1",
        role: "lead",
        kind: "change",
        label: "通勤",
        statement: "通勤比上一段多了 2 笔。",
        evidenceCount: 4,
      },
    ],
  };
}

function validDayResponse() {
  return {
    rewrites: [
      {
        scope: "day",
        periodKey: "2026-07-22",
        headline: "今天的记录",
        summary: "3 笔记录按发生顺序排在一起。",
        supportingLine: "咖啡仍是生活线索。",
        evidenceIDs: ["F1", "F2"],
      },
    ],
  };
}

test("accepts a valid evidence-backed narrative rewrite batch", () => {
  const expected = validDayResponse();
  assert.deepEqual(normalizeNarrativeRewriteBatch(JSON.stringify(expected), [dayPack()]), expected);
});

test("accepts a fenced JSON response and normalizes whitespace", () => {
  const response = validDayResponse();
  response.rewrites[0].headline = "  今天的记录  ";
  const normalized = normalizeNarrativeRewriteBatch(
    `\`\`\`json\n${JSON.stringify(response)}\n\`\`\``,
    [dayPack()]
  );
  assert.equal(normalized.rewrites[0].headline, "今天的记录");
});

test("rejects unknown evidence, mismatched periods, and invented numbers", () => {
  const unknownEvidence = validDayResponse();
  unknownEvidence.rewrites[0].evidenceIDs = ["F1", "F3"];
  assert.equal(normalizeNarrativeRewriteBatch(JSON.stringify(unknownEvidence), [dayPack()]), null);

  const wrongPeriod = validDayResponse();
  wrongPeriod.rewrites[0].periodKey = "2026-07-21";
  assert.equal(normalizeNarrativeRewriteBatch(JSON.stringify(wrongPeriod), [dayPack()]), null);

  const inventedNumber = validDayResponse();
  inventedNumber.rewrites[0].summary = "9 笔记录按发生顺序排在一起。";
  assert.equal(normalizeNarrativeRewriteBatch(JSON.stringify(inventedNumber), [dayPack()]), null);
});

test("rejects duplicate response scopes and inference copy", () => {
  const response = validDayResponse();
  response.rewrites.push({ ...response.rewrites[0], summary: "3 笔记录仍按发生顺序排在一起。" });
  assert.equal(
    normalizeNarrativeRewriteBatch(JSON.stringify(response), [dayPack(), monthPack()]),
    null
  );

  const inferred = validDayResponse();
  inferred.rewrites[0].summary = "因为 3 笔记录，你今天一定很努力。";
  assert.equal(normalizeNarrativeRewriteBatch(JSON.stringify(inferred), [dayPack()]), null);
});

test("rejects malformed, unredacted, and identifier-bearing fact packs", () => {
  assert.equal(validateNarrativeFactPacks([]).ok, false);
  assert.equal(validateNarrativeFactPacks([dayPack(), dayPack()]).ok, false);

  const extraField = dayPack();
  extraField.rawTitle = "不应上传";
  assert.equal(validateNarrativeFactPacks([extraField]).ok, false);

  const unredactedUserText = dayPack();
  unredactedUserText.facts[0] = {
    id: "F1",
    role: "lead",
    kind: "userText",
    label: "我今天见了某个人",
    statement: "今天有 1 条用户主动写下的记录。",
    evidenceCount: 1,
  };
  assert.equal(validateNarrativeFactPacks([unredactedUserText]).ok, false);

  const identifier = dayPack();
  identifier.facts[0].statement = "记录 550e8400-e29b-41d4-a716-446655440000";
  assert.equal(validateNarrativeFactPacks([identifier]).ok, false);
});

test("builds the narrative prompt on the server from validated facts", () => {
  const messages = buildNarrativeRewriteMessages([dayPack()], "neutral");
  assert.equal(messages.length, 2);
  assert.match(messages[0].content, /语气为中性/);
  assert.match(messages[1].content, /脱敏事实包/);
  assert.match(messages[1].content, /2026-07-22/);
  assert.equal(buildNarrativeRewriteMessages([], "gentle"), null);
});

test("keeps the legacy daily insight response contract unchanged", () => {
  assert.deepEqual(
    normalizeInsightPayload('{"summary":"今天比较平稳","action":"照常记录","encourage":"已经记下来了"}'),
    {
      summary: "今天比较平稳",
      action: "照常记录",
      encourage: "已经记下来了",
    }
  );
  assert.deepEqual(normalizeInsightPayload("普通文本"), {
    summary: "普通文本",
    action: "继续按你的节奏记录，慢慢就会更清晰。",
    encourage: "你已经在认真照顾自己的生活啦。",
  });
});

test("allows only known features before rate limiting", () => {
  assert.equal(normalizedSupportedFeature(undefined), "daily");
  assert.equal(normalizedSupportedFeature("MONTHLY"), "monthly");
  assert.equal(normalizedSupportedFeature("narrative_rewrite_batch"), "narrative_rewrite_batch");
  assert.equal(normalizedSupportedFeature("daily-user-controlled-suffix"), null);
});
