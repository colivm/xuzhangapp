process.env.NODE_ENV = "test";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  COVER_DIRECTOR_RESPONSE_JSON_SCHEMA,
  buildCoverDirectorMessages,
  normalizeCoverDirectorResponse,
  validateCoverDirectorRequest,
} = require("./coverDirectorContract");
const { normalizedSupportedFeature } = require("./aiFeaturePolicy");

const TWENTY_TEMPLATE_IDS = [
  "heroStory", "magazine", "memoryFocus", "journal", "film",
  "minimal", "quote", "timeline", "postcard", "scrapbook",
  "editorial", "memoryWall", "travelNote", "bookCover", "natureDiary",
  "coffeeStory", "warmHome", "nightStory", "ocean", "quietEditorial",
];

const TEMPLATE_CAPABILITIES = {
  heroStory: [1, 3, true, true, false],
  magazine: [2, 3, true, true, false],
  memoryFocus: [1, 1, true, true, false],
  journal: [0, 2, false, false, false],
  film: [2, 4, true, true, false],
  minimal: [0, 1, false, false, true],
  quote: [0, 1, false, false, false],
  timeline: [0, 3, false, true, false],
  postcard: [1, 2, true, true, false],
  scrapbook: [3, 5, true, true, false],
  editorial: [2, 3, true, true, false],
  memoryWall: [4, 6, true, true, false],
  travelNote: [2, 3, true, true, false],
  bookCover: [1, 1, true, true, false],
  natureDiary: [1, 3, true, true, false],
  coffeeStory: [1, 2, true, true, false],
  warmHome: [1, 3, true, true, false],
  nightStory: [1, 3, true, true, false],
  ocean: [1, 3, true, true, false],
  quietEditorial: [0, 2, false, false, true],
};

function singleTemplateRequest(templateID, availableMediaCount) {
  const [minimumMediaCount, maximumMediaCount, requiresHero, allowsHero, allowsDecoration] =
    TEMPLATE_CAPABILITIES[templateID];
  const renderedMediaCount = Math.min(availableMediaCount, maximumMediaCount);
  const candidate = {
    templateID,
    variantID: `launch.${templateID}.standard-copy.media-${renderedMediaCount}`,
    allowedPaletteIDs: ["creamMorning"],
    allowedBackgroundFamilies: ["morningLight"],
    allowedAnimationProfiles: ["gentleEditorial"],
    minimumMediaCount,
    maximumMediaCount,
    requiresHero,
    allowsHero,
    allowsDecoration,
  };
  return {
    schemaVersion: 1,
    sourceRevision: 84,
    periodKeyHash: "h01234567x89abcdef",
    contentFingerprint: "hfedcba98x76543210",
    facts: {
      leadCharacterCount: 18,
      hasSupport: true,
      markCount: 1,
      timelineCount: 3,
      recordedDayCount: 7,
      availablePhotoCount: availableMediaCount,
    },
    templateCandidates: [candidate],
    mediaCandidates: Array.from({ length: availableMediaCount }, (_, index) => ({
      alias: `M${index + 1}`,
      orientation: index === 0 ? "portrait" : index % 2 === 0 ? "square" : "landscape",
      qualityBand: index === 0 ? "strong" : "usable",
      isHeroEligible: true,
      isEvidenceBoundToLead: true,
    })),
    fallback: {
      templateID,
      variantID: candidate.variantID,
      paletteID: "creamMorning",
      backgroundFamily: "morningLight",
      animationProfile: "gentleEditorial",
      seed: 4284,
    },
  };
}

function responseForSingleTemplate(request, mediaRoles) {
  return {
    schemaVersion: 1,
    sourceRevision: request.sourceRevision,
    periodKeyHash: request.periodKeyHash,
    contentFingerprint: request.contentFingerprint,
    templateID: request.fallback.templateID,
    variantID: request.fallback.variantID,
    paletteID: request.fallback.paletteID,
    backgroundFamily: request.fallback.backgroundFamily,
    mediaRoles,
    animationProfile: request.fallback.animationProfile,
    seed: request.fallback.seed,
    confidence: 0.84,
    reasonCodes: mediaRoles.some((item) => item.role === "hero")
      ? ["strongPhotoLead"]
      : ["shortStory"],
  };
}

function requestFixture() {
  return {
    schemaVersion: 1,
    sourceRevision: 42,
    periodKeyHash: "h01234567x89abcdef",
    contentFingerprint: "hfedcba98x76543210",
    facts: {
      leadCharacterCount: 18,
      hasSupport: true,
      markCount: 1,
      timelineCount: 3,
      recordedDayCount: 4,
      availablePhotoCount: 2,
    },
    templateCandidates: [
      {
        templateID: "heroStory",
        variantID: "launch.heroStory.standard-copy.media-2",
        allowedPaletteIDs: ["creamMorning", "warmBeige"],
        allowedBackgroundFamilies: ["morningLight", "warmHome"],
        allowedAnimationProfiles: ["gentleEditorial"],
        minimumMediaCount: 1,
        maximumMediaCount: 3,
        requiresHero: true,
        allowsHero: true,
        allowsDecoration: false,
      },
      {
        templateID: "journal",
        variantID: "launch.journal.standard-copy.media-2",
        allowedPaletteIDs: ["warmBeige", "paperGray"],
        allowedBackgroundFamilies: ["journal", "creamPaper"],
        allowedAnimationProfiles: ["paperReveal"],
        minimumMediaCount: 0,
        maximumMediaCount: 2,
        requiresHero: false,
        allowsHero: false,
        allowsDecoration: false,
      },
    ],
    mediaCandidates: [
      {
        alias: "M1",
        orientation: "portrait",
        qualityBand: "strong",
        isHeroEligible: true,
        isEvidenceBoundToLead: true,
      },
      {
        alias: "M2",
        orientation: "landscape",
        qualityBand: "usable",
        isHeroEligible: false,
        isEvidenceBoundToLead: false,
      },
    ],
    fallback: {
      templateID: "heroStory",
      variantID: "launch.heroStory.standard-copy.media-2",
      paletteID: "creamMorning",
      backgroundFamily: "morningLight",
      animationProfile: "gentleEditorial",
      seed: 89121,
    },
  };
}

function responseFixture() {
  return {
    schemaVersion: 1,
    sourceRevision: 42,
    periodKeyHash: "h01234567x89abcdef",
    contentFingerprint: "hfedcba98x76543210",
    templateID: "heroStory",
    variantID: "launch.heroStory.standard-copy.media-2",
    paletteID: "warmBeige",
    backgroundFamily: "warmHome",
    mediaRoles: [
      { mediaAlias: "M1", role: "hero" },
      { mediaAlias: "M2", role: "secondary" },
    ],
    animationProfile: "gentleEditorial",
    seed: 89121,
    confidence: 0.86,
    reasonCodes: ["strongPhotoLead", "strongSupport"],
  };
}

test("accepts a redacted bounded cover director request", () => {
  const request = requestFixture();
  assert.deepEqual(validateCoverDirectorRequest(request), { ok: true });
  const serialized = JSON.stringify(request);
  assert.doesNotMatch(serialized, /storyText|headline|photoData|imageData|imageReference|evidenceItemIDs|messages/);
  assert.doesNotMatch(serialized, /[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/i);
});

test("rejects free text image fields identifiers and unknown request keys", () => {
  for (const forbiddenField of ["storyText", "headline", "photoData", "imageReference", "messages"]) {
    const request = requestFixture();
    request[forbiddenField] = "不应上传";
    assert.equal(validateCoverDirectorRequest(request).ok, false);
  }

  const uuidAlias = requestFixture();
  uuidAlias.mediaCandidates[0].alias = "550e8400-e29b-41d4-a716-446655440000";
  assert.equal(validateCoverDirectorRequest(uuidAlias).ok, false);

  const extraCandidate = requestFixture();
  extraCandidate.templateCandidates[0].allowedPaletteIDs.push("unboundedPalette");
  assert.equal(validateCoverDirectorRequest(extraCandidate).ok, false);
});

test("server builds the director prompt only after contract validation", () => {
  const messages = buildCoverDirectorMessages(requestFixture());
  assert.equal(messages.length, 2);
  assert.match(messages[0].content, /受约束导演/);
  assert.match(messages[0].content, /JSON Schema/);
  assert.match(messages[1].content, /脱敏导演输入/);
  assert.doesNotMatch(messages[1].content, /账本 UUID|故事正文|照片字节/);

  const invalid = requestFixture();
  invalid.rawUserStory = "今天见了某个人";
  assert.equal(buildCoverDirectorMessages(invalid), null);
});

test("normalizes a valid response and binds it to the exact request", () => {
  const request = requestFixture();
  const response = responseFixture();
  assert.deepEqual(
    normalizeCoverDirectorResponse(JSON.stringify(response), request),
    response
  );
  assert.deepEqual(
    normalizeCoverDirectorResponse(`\`\`\`json\n${JSON.stringify(response)}\n\`\`\``, request),
    response
  );
});

test("rejects stale identities unknown tokens and unsupported media roles", () => {
  const request = requestFixture();
  const mutations = [
    (response) => { response.sourceRevision = 41; },
    (response) => { response.templateID = "scrapbook"; },
    (response) => { response.paletteID = "oceanBlue"; },
    (response) => { response.backgroundFamily = "postcard"; },
    (response) => { response.mediaRoles[0].mediaAlias = "M3"; },
    (response) => { response.mediaRoles[1].role = "decoration"; },
    (response) => { response.extra = "not allowed"; },
  ];
  for (const mutate of mutations) {
    const response = responseFixture();
    mutate(response);
    assert.equal(normalizeCoverDirectorResponse(JSON.stringify(response), request), null);
  }

  const unboundRequest = requestFixture();
  unboundRequest.mediaCandidates[0].isEvidenceBoundToLead = false;
  assert.equal(
    normalizeCoverDirectorResponse(JSON.stringify(responseFixture()), unboundRequest),
    null
  );
});

test("publishes a closed response JSON Schema and registers only the known feature", () => {
  assert.equal(COVER_DIRECTOR_RESPONSE_JSON_SCHEMA.additionalProperties, false);
  assert.equal(COVER_DIRECTOR_RESPONSE_JSON_SCHEMA.properties.mediaRoles.items.additionalProperties, false);
  assert.equal(normalizedSupportedFeature("cover_director"), "cover_director");
  assert.equal(normalizedSupportedFeature("cover_director_with_photos"), null);
});

test("publishes exactly the twenty template IDs in the closed response schema", () => {
  assert.deepEqual(
    COVER_DIRECTOR_RESPONSE_JSON_SCHEMA.properties.templateID.enum,
    TWENTY_TEMPLATE_IDS
  );
  assert.equal(COVER_DIRECTOR_RESPONSE_JSON_SCHEMA.properties.mediaRoles.maxItems, 6);
});

test("accepts bounded requests and responses for all twenty templates", () => {
  for (const templateID of TWENTY_TEMPLATE_IDS) {
    const [minimumMediaCount, , requiresHero, allowsHero, allowsDecoration] =
      TEMPLATE_CAPABILITIES[templateID];
    const request = singleTemplateRequest(templateID, minimumMediaCount);
    assert.deepEqual(validateCoverDirectorRequest(request), { ok: true }, templateID);

    const mediaRoles = request.mediaCandidates.map((media, index) => ({
      mediaAlias: media.alias,
      role: requiresHero && index === 0
        ? "hero"
        : allowsDecoration
          ? "decoration"
          : "secondary",
    }));
    if (!allowsHero) {
      assert.equal(mediaRoles.some((item) => item.role === "hero"), false);
    }
    const response = responseForSingleTemplate(request, mediaRoles);
    assert.deepEqual(
      normalizeCoverDirectorResponse(JSON.stringify(response), request),
      response,
      templateID
    );
  }
});

test("memoryWall accepts four through six asymmetric media slots", () => {
  for (const mediaCount of [4, 5, 6]) {
    const request = singleTemplateRequest("memoryWall", mediaCount);
    const mediaRoles = request.mediaCandidates.map((media, index) => ({
      mediaAlias: media.alias,
      role: index === 0 ? "hero" : "secondary",
    }));
    const response = responseForSingleTemplate(request, mediaRoles);
    assert.deepEqual(
      normalizeCoverDirectorResponse(JSON.stringify(response), request),
      response
    );
  }

  const request = singleTemplateRequest("memoryWall", 4);
  const tooFew = responseForSingleTemplate(request, [
    { mediaAlias: "M1", role: "hero" },
    { mediaAlias: "M2", role: "secondary" },
    { mediaAlias: "M3", role: "secondary" },
  ]);
  assert.equal(normalizeCoverDirectorResponse(JSON.stringify(tooFew), request), null);
});

test("quietEditorial accepts decoration only and rejects hero or secondary roles", () => {
  const request = singleTemplateRequest("quietEditorial", 2);
  const decorations = responseForSingleTemplate(request, [
    { mediaAlias: "M1", role: "decoration" },
    { mediaAlias: "M2", role: "decoration" },
  ]);
  assert.deepEqual(
    normalizeCoverDirectorResponse(JSON.stringify(decorations), request),
    decorations
  );

  for (const forbiddenRole of ["hero", "secondary"]) {
    const invalid = structuredClone(decorations);
    invalid.mediaRoles[0].role = forbiddenRole;
    assert.equal(normalizeCoverDirectorResponse(JSON.stringify(invalid), request), null);
  }
});

test("bookCover accepts a portrait hero and rejects landscape or square heroes", () => {
  const request = singleTemplateRequest("bookCover", 1);
  const response = responseForSingleTemplate(request, [
    { mediaAlias: "M1", role: "hero" },
  ]);
  assert.deepEqual(
    normalizeCoverDirectorResponse(JSON.stringify(response), request),
    response
  );

  for (const orientation of ["landscape", "square"]) {
    const invalidRequest = structuredClone(request);
    invalidRequest.mediaCandidates[0].orientation = orientation;
    assert.deepEqual(validateCoverDirectorRequest(invalidRequest), { ok: true });
    assert.equal(
      normalizeCoverDirectorResponse(JSON.stringify(response), invalidRequest),
      null
    );
  }
});

test("allows media-6 variants and rejects media-7 variants", () => {
  const mediaSix = singleTemplateRequest("memoryWall", 6);
  assert.deepEqual(validateCoverDirectorRequest(mediaSix), { ok: true });

  const availableSeven = singleTemplateRequest("memoryWall", 7);
  assert.equal(availableSeven.templateCandidates[0].variantID.endsWith("media-6"), true);
  assert.deepEqual(validateCoverDirectorRequest(availableSeven), { ok: true });

  availableSeven.templateCandidates[0].variantID =
    "launch.memoryWall.standard-copy.media-7";
  availableSeven.fallback.variantID = "launch.memoryWall.standard-copy.media-7";
  assert.equal(validateCoverDirectorRequest(availableSeven).ok, false);
});
