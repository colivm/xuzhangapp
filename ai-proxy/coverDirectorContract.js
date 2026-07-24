const LAUNCH_TEMPLATES = Object.freeze({
  heroStory: { minimumMediaCount: 1, maximumMediaCount: 3, requiresHero: true, allowsHero: true, allowsDecoration: false },
  magazine: { minimumMediaCount: 2, maximumMediaCount: 3, requiresHero: true, allowsHero: true, allowsDecoration: false },
  memoryFocus: { minimumMediaCount: 1, maximumMediaCount: 1, requiresHero: true, allowsHero: true, allowsDecoration: false },
  journal: { minimumMediaCount: 0, maximumMediaCount: 2, requiresHero: false, allowsHero: false, allowsDecoration: false },
  film: { minimumMediaCount: 2, maximumMediaCount: 4, requiresHero: true, allowsHero: true, allowsDecoration: false },
  minimal: { minimumMediaCount: 0, maximumMediaCount: 1, requiresHero: false, allowsHero: false, allowsDecoration: true },
  quote: { minimumMediaCount: 0, maximumMediaCount: 1, requiresHero: false, allowsHero: false, allowsDecoration: false },
  timeline: { minimumMediaCount: 0, maximumMediaCount: 3, requiresHero: false, allowsHero: true, allowsDecoration: false },
  postcard: { minimumMediaCount: 1, maximumMediaCount: 2, requiresHero: true, allowsHero: true, allowsDecoration: false },
  scrapbook: { minimumMediaCount: 3, maximumMediaCount: 5, requiresHero: true, allowsHero: true, allowsDecoration: false },
  editorial: { minimumMediaCount: 2, maximumMediaCount: 3, requiresHero: true, allowsHero: true, allowsDecoration: false },
  memoryWall: { minimumMediaCount: 4, maximumMediaCount: 6, requiresHero: true, allowsHero: true, allowsDecoration: false },
  travelNote: { minimumMediaCount: 2, maximumMediaCount: 3, requiresHero: true, allowsHero: true, allowsDecoration: false },
  bookCover: { minimumMediaCount: 1, maximumMediaCount: 1, requiresHero: true, allowsHero: true, allowsDecoration: false },
  natureDiary: { minimumMediaCount: 1, maximumMediaCount: 3, requiresHero: true, allowsHero: true, allowsDecoration: false },
  coffeeStory: { minimumMediaCount: 1, maximumMediaCount: 2, requiresHero: true, allowsHero: true, allowsDecoration: false },
  warmHome: { minimumMediaCount: 1, maximumMediaCount: 3, requiresHero: true, allowsHero: true, allowsDecoration: false },
  nightStory: { minimumMediaCount: 1, maximumMediaCount: 3, requiresHero: true, allowsHero: true, allowsDecoration: false },
  ocean: { minimumMediaCount: 1, maximumMediaCount: 3, requiresHero: true, allowsHero: true, allowsDecoration: false },
  quietEditorial: { minimumMediaCount: 0, maximumMediaCount: 2, requiresHero: false, allowsHero: false, allowsDecoration: true },
});

const ALLOWED_PALETTES = new Set([
  "creamMorning",
  "warmBeige",
  "fogGreen",
  "coffeeBrown",
  "nightBlue",
  "paperGray",
  "oceanBlue",
  "quietCream",
]);
const ALLOWED_BACKGROUNDS = new Set([
  "morningLight",
  "warmHome",
  "sunset",
  "nightWalk",
  "editorial",
  "paperGray",
  "journal",
  "creamPaper",
  "coffeeTime",
  "minimal",
  "quietEditorial",
  "film",
  "forestDiary",
  "travelNote",
  "nature",
  "bookCover",
  "ocean",
  "autumn",
  "postcard",
  "softUtility",
]);
const ALLOWED_ANIMATIONS = new Set([
  "gentleEditorial",
  "paperReveal",
  "sequentialDevelop",
  "quietFade",
]);
const ALLOWED_REASONS = new Set([
  "strongPhotoLead",
  "balancedPhotoSet",
  "shortStory",
  "strongSupport",
  "timelineEvidence",
  "noEligiblePhoto",
]);
const ALLOWED_MEDIA_ROLES = new Set(["hero", "secondary", "decoration"]);
const HASH_PATTERN = /^h[0-9a-f]{8}x[0-9a-f]{8}$/;
const VARIANT_PATTERN = /^launch\.(heroStory|magazine|memoryFocus|journal|film|minimal|quote|timeline|postcard|scrapbook|editorial|memoryWall|travelNote|bookCover|natureDiary|coffeeStory|warmHome|nightStory|ocean|quietEditorial)\.(standard-copy|long-copy)\.media-[0-6]$/;

const COVER_DIRECTOR_RESPONSE_JSON_SCHEMA = Object.freeze({
  type: "object",
  additionalProperties: false,
  required: [
    "schemaVersion",
    "sourceRevision",
    "periodKeyHash",
    "contentFingerprint",
    "templateID",
    "variantID",
    "paletteID",
    "backgroundFamily",
    "mediaRoles",
    "animationProfile",
    "seed",
    "confidence",
    "reasonCodes",
  ],
  properties: {
    schemaVersion: { type: "integer", const: 1 },
    sourceRevision: { type: "integer", minimum: 0 },
    periodKeyHash: { type: "string", pattern: "^h[0-9a-f]{8}x[0-9a-f]{8}$" },
    contentFingerprint: { type: "string", pattern: "^h[0-9a-f]{8}x[0-9a-f]{8}$" },
    templateID: { type: "string", enum: Object.keys(LAUNCH_TEMPLATES) },
    variantID: { type: "string", pattern: VARIANT_PATTERN.source },
    paletteID: { type: "string", enum: [...ALLOWED_PALETTES] },
    backgroundFamily: { type: "string", enum: [...ALLOWED_BACKGROUNDS] },
    mediaRoles: {
      type: "array",
      maxItems: 6,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["mediaAlias", "role"],
        properties: {
          mediaAlias: { type: "string", pattern: "^M[1-7]$" },
          role: { type: "string", enum: [...ALLOWED_MEDIA_ROLES] },
        },
      },
    },
    animationProfile: { type: "string", enum: [...ALLOWED_ANIMATIONS] },
    seed: { type: "integer", minimum: 0, maximum: 2147483647 },
    confidence: { type: "number", minimum: 0, maximum: 1 },
    reasonCodes: {
      type: "array",
      minItems: 1,
      maxItems: 4,
      uniqueItems: true,
      items: { type: "string", enum: [...ALLOWED_REASONS] },
    },
  },
});

function validateCoverDirectorRequest(rawRequest) {
  if (!isPlainObject(rawRequest) || !hasOnlyKeys(rawRequest, [
    "schemaVersion",
    "sourceRevision",
    "periodKeyHash",
    "contentFingerprint",
    "facts",
    "templateCandidates",
    "mediaCandidates",
    "fallback",
  ])) return invalid("director request has unsupported fields");

  if (rawRequest.schemaVersion !== 1 || !nonnegativeInteger(rawRequest.sourceRevision)) {
    return invalid("director request identity is invalid");
  }
  if (!HASH_PATTERN.test(rawRequest.periodKeyHash) || !HASH_PATTERN.test(rawRequest.contentFingerprint)) {
    return invalid("director request hash is invalid");
  }
  if (!validateFacts(rawRequest.facts)) return invalid("director fact summary is invalid");
  if (!Array.isArray(rawRequest.templateCandidates) || rawRequest.templateCandidates.length < 1 || rawRequest.templateCandidates.length > 5) {
    return invalid("director request must contain 1 to 5 template candidates");
  }
  if (!Array.isArray(rawRequest.mediaCandidates) || rawRequest.mediaCandidates.length > 7) {
    return invalid("director media candidate count is invalid");
  }

  const seenTemplates = new Set();
  for (const candidate of rawRequest.templateCandidates) {
    if (!validateTemplateCandidate(candidate) || seenTemplates.has(candidate.templateID)) {
      return invalid("director template candidate is invalid or duplicated");
    }
    seenTemplates.add(candidate.templateID);
  }

  const seenAliases = new Set();
  for (let index = 0; index < rawRequest.mediaCandidates.length; index += 1) {
    const media = rawRequest.mediaCandidates[index];
    if (!validateMediaCandidate(media, `M${index + 1}`) || seenAliases.has(media.alias)) {
      return invalid("director media candidate is invalid or duplicated");
    }
    seenAliases.add(media.alias);
  }
  if (rawRequest.facts.availablePhotoCount !== rawRequest.mediaCandidates.length) {
    return invalid("director media count does not match fact summary");
  }
  if (!validateFallback(rawRequest.fallback, rawRequest.templateCandidates)) {
    return invalid("director fallback is invalid");
  }
  return { ok: true };
}

function normalizeCoverDirectorResponse(content, rawRequest) {
  if (!validateCoverDirectorRequest(rawRequest).ok || typeof content !== "string") return null;
  const object = parseJSONObject(content);
  const keys = COVER_DIRECTOR_RESPONSE_JSON_SCHEMA.required;
  if (!isPlainObject(object) || !hasOnlyKeys(object, keys)) return null;
  if (
    object.schemaVersion !== 1 ||
    object.sourceRevision !== rawRequest.sourceRevision ||
    object.periodKeyHash !== rawRequest.periodKeyHash ||
    object.contentFingerprint !== rawRequest.contentFingerprint
  ) return null;

  const candidate = rawRequest.templateCandidates.find((item) => item.templateID === object.templateID);
  if (!candidate || object.variantID !== candidate.variantID) return null;
  if (!candidate.allowedPaletteIDs.includes(object.paletteID)) return null;
  if (!candidate.allowedBackgroundFamilies.includes(object.backgroundFamily)) return null;
  if (!candidate.allowedAnimationProfiles.includes(object.animationProfile)) return null;
  if (!Number.isInteger(object.seed) || object.seed < 0 || object.seed > 2147483647) return null;
  if (!Number.isFinite(object.confidence) || object.confidence < 0 || object.confidence > 1) return null;
  if (!Array.isArray(object.reasonCodes) || object.reasonCodes.length < 1 || object.reasonCodes.length > 4) return null;
  if (new Set(object.reasonCodes).size !== object.reasonCodes.length || object.reasonCodes.some((reason) => !ALLOWED_REASONS.has(reason))) return null;
  if (!Array.isArray(object.mediaRoles) || object.mediaRoles.length < candidate.minimumMediaCount || object.mediaRoles.length > candidate.maximumMediaCount) return null;

  const mediaByAlias = new Map(rawRequest.mediaCandidates.map((media) => [media.alias, media]));
  const seenAliases = new Set();
  let heroCount = 0;
  for (const mediaRole of object.mediaRoles) {
    if (!isPlainObject(mediaRole) || !hasOnlyKeys(mediaRole, ["mediaAlias", "role"])) return null;
    if (!ALLOWED_MEDIA_ROLES.has(mediaRole.role) || seenAliases.has(mediaRole.mediaAlias)) return null;
    const media = mediaByAlias.get(mediaRole.mediaAlias);
    if (!media) return null;
    if (mediaRole.role === "hero") {
      heroCount += 1;
      if (!candidate.allowsHero || !media.isHeroEligible || !media.isEvidenceBoundToLead) return null;
      if (candidate.templateID === "bookCover" && media.orientation !== "portrait") return null;
    }
    if (mediaRole.role === "secondary" && candidate.allowsDecoration) return null;
    if (mediaRole.role === "decoration" && !candidate.allowsDecoration) return null;
    seenAliases.add(mediaRole.mediaAlias);
  }
  if (heroCount > 1 || (candidate.requiresHero && heroCount !== 1) || (!candidate.allowsHero && heroCount !== 0)) return null;
  if (object.reasonCodes.includes("strongPhotoLead") && heroCount !== 1) return null;
  if (object.reasonCodes.includes("balancedPhotoSet") && object.mediaRoles.length < 2) return null;
  if (object.reasonCodes.includes("shortStory") && rawRequest.facts.leadCharacterCount > 30) return null;
  if (object.reasonCodes.includes("strongSupport") && !rawRequest.facts.hasSupport) return null;
  if (object.reasonCodes.includes("timelineEvidence") && rawRequest.facts.timelineCount < 3) return null;
  if (object.reasonCodes.includes("noEligiblePhoto") && rawRequest.facts.availablePhotoCount !== 0) return null;

  return {
    schemaVersion: 1,
    sourceRevision: rawRequest.sourceRevision,
    periodKeyHash: rawRequest.periodKeyHash,
    contentFingerprint: rawRequest.contentFingerprint,
    templateID: object.templateID,
    variantID: object.variantID,
    paletteID: object.paletteID,
    backgroundFamily: object.backgroundFamily,
    mediaRoles: object.mediaRoles.map((item) => ({ mediaAlias: item.mediaAlias, role: item.role })),
    animationProfile: object.animationProfile,
    seed: object.seed,
    confidence: object.confidence,
    reasonCodes: object.reasonCodes,
  };
}

function buildCoverDirectorMessages(rawRequest) {
  if (!validateCoverDirectorRequest(rawRequest).ok) return null;
  const systemContent = [
    "你是叙账分享封面的受约束导演，不是文案作者、图片识别器或布局代码生成器。",
    "输入只有脱敏的结构化数量、方向、质量档位、匿名媒体别名和本地已判定合法的候选 token。",
    "只能从 templateCandidates 中选一个模板及其原样 variantID、paletteID、backgroundFamily、animationProfile。",
    "mediaRoles 只能引用输入的 M 编号；Hero 必须同时 isHeroEligible=true 且 isEvidenceBoundToLead=true。",
    "bookCover 的 Hero 必须是 portrait；不得把 landscape 或 square 媒体放进书封 Hero。",
    "不得输出正文、图片描述、坐标、字体、二维码、URL、UUID、额外字段或候选之外的 token。",
    "优先让故事主体明确、Hero 与辅助图有主次；证据弱或图片弱时选择 journal、quote 或 minimal。",
    `严格输出一个符合此 JSON Schema 的 JSON 对象：${JSON.stringify(COVER_DIRECTOR_RESPONSE_JSON_SCHEMA)}`,
  ].join("\n");
  return [
    { role: "system", content: systemContent },
    { role: "user", content: `脱敏导演输入：${JSON.stringify(rawRequest)}` },
  ];
}

function validateFacts(facts) {
  if (!isPlainObject(facts) || !hasOnlyKeys(facts, [
    "leadCharacterCount",
    "hasSupport",
    "markCount",
    "timelineCount",
    "recordedDayCount",
    "availablePhotoCount",
  ])) return false;
  return Number.isInteger(facts.leadCharacterCount) && facts.leadCharacterCount >= 1 && facts.leadCharacterCount <= 500 &&
    typeof facts.hasSupport === "boolean" &&
    integerInRange(facts.markCount, 0, 2) &&
    integerInRange(facts.timelineCount, 0, 4) &&
    integerInRange(facts.recordedDayCount, 0, 366) &&
    integerInRange(facts.availablePhotoCount, 0, 7);
}

function validateTemplateCandidate(candidate) {
  if (!isPlainObject(candidate) || !hasOnlyKeys(candidate, [
    "templateID",
    "variantID",
    "allowedPaletteIDs",
    "allowedBackgroundFamilies",
    "allowedAnimationProfiles",
    "minimumMediaCount",
    "maximumMediaCount",
    "requiresHero",
    "allowsHero",
    "allowsDecoration",
  ])) return false;
  const expected = LAUNCH_TEMPLATES[candidate.templateID];
  if (!expected || !VARIANT_PATTERN.test(candidate.variantID) || !candidate.variantID.startsWith(`launch.${candidate.templateID}.`)) return false;
  if (
    candidate.minimumMediaCount !== expected.minimumMediaCount ||
    candidate.maximumMediaCount !== expected.maximumMediaCount ||
    candidate.requiresHero !== expected.requiresHero ||
    candidate.allowsHero !== expected.allowsHero ||
    candidate.allowsDecoration !== expected.allowsDecoration
  ) return false;
  return validUniqueTokenArray(candidate.allowedPaletteIDs, ALLOWED_PALETTES, 1, 4) &&
    validUniqueTokenArray(candidate.allowedBackgroundFamilies, ALLOWED_BACKGROUNDS, 1, 4) &&
    validUniqueTokenArray(candidate.allowedAnimationProfiles, ALLOWED_ANIMATIONS, 1, 1);
}

function validateMediaCandidate(media, expectedAlias) {
  return isPlainObject(media) && hasOnlyKeys(media, [
    "alias",
    "orientation",
    "qualityBand",
    "isHeroEligible",
    "isEvidenceBoundToLead",
  ]) && media.alias === expectedAlias &&
    ["portrait", "landscape", "square"].includes(media.orientation) &&
    ["strong", "usable", "limited"].includes(media.qualityBand) &&
    typeof media.isHeroEligible === "boolean" &&
    typeof media.isEvidenceBoundToLead === "boolean";
}

function validateFallback(fallback, candidates) {
  if (!isPlainObject(fallback) || !hasOnlyKeys(fallback, [
    "templateID",
    "variantID",
    "paletteID",
    "backgroundFamily",
    "animationProfile",
    "seed",
  ])) return false;
  const candidate = candidates.find((item) => item.templateID === fallback.templateID);
  return Boolean(candidate) && fallback.variantID === candidate.variantID &&
    candidate.allowedPaletteIDs.includes(fallback.paletteID) &&
    candidate.allowedBackgroundFamilies.includes(fallback.backgroundFamily) &&
    candidate.allowedAnimationProfiles.includes(fallback.animationProfile) &&
    Number.isInteger(fallback.seed) && fallback.seed >= 0 && fallback.seed <= 2147483647;
}

function validUniqueTokenArray(values, allowList, minimum, maximum) {
  return Array.isArray(values) && values.length >= minimum && values.length <= maximum &&
    new Set(values).size === values.length && values.every((value) => allowList.has(value));
}

function parseJSONObject(content) {
  const trimmed = content.replace(/```json/gi, "").replace(/```/g, "").trim();
  try {
    const direct = JSON.parse(trimmed);
    if (isPlainObject(direct)) return direct;
  } catch (_error) {}
  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    const sliced = JSON.parse(trimmed.slice(start, end + 1));
    return isPlainObject(sliced) ? sliced : null;
  } catch (_error) {
    return null;
  }
}

function nonnegativeInteger(value) {
  return Number.isInteger(value) && value >= 0;
}

function integerInRange(value, minimum, maximum) {
  return Number.isInteger(value) && value >= minimum && value <= maximum;
}

function isPlainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function hasOnlyKeys(object, allowedKeys) {
  const allowed = new Set(allowedKeys);
  const keys = Object.keys(object);
  return keys.length === allowed.size && keys.every((key) => allowed.has(key));
}

function invalid(reason) {
  return { ok: false, error: "COVER_DIRECTOR_CONTRACT_REJECTED", reason };
}

module.exports = {
  COVER_DIRECTOR_RESPONSE_JSON_SCHEMA,
  buildCoverDirectorMessages,
  normalizeCoverDirectorResponse,
  validateCoverDirectorRequest,
};
