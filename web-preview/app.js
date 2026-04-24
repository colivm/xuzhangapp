const STORAGE_KEY = "qingzhang_preview_v1";
const GUIDE_KEY = "qingzhang_preview_guide_done_v1";
const categories = [
  { value: "餐饮", label: "吃饭", icon: "🍜" },
  { value: "购物", label: "买东西", icon: "🛍️" },
  { value: "交通", label: "出行", icon: "🚌" },
  { value: "娱乐", label: "玩", icon: "🎡" },
  { value: "日用", label: "生活", icon: "🧸" },
  { value: "其他", label: "随便", icon: "🌟" },
];
const guideCards = [
  {
    title: "1 分钟快速记账",
    desc: "打开就能记，描述可选，支持补记，不给你负担。",
  },
  {
    title: "AI 帮你看懂钱花去哪",
    desc: "每天一条温和建议，不说教，只给你可执行的小提醒。",
  },
  {
    title: "数据只在你手机里",
    desc: "默认本地存储，不强制登录，隐私可控更安心。",
  },
];
const noteSuggestionMap = {
  午: ["午餐", "外卖", "食堂"],
  晚: ["晚餐", "夜宵", "聚餐"],
  早: ["早餐", "豆浆", "面包"],
  咖: ["咖啡", "奶茶", "饮品"],
  地: ["地铁", "公交", "打车"],
};
const memberScenePacks = [
  {
    id: "commute",
    emoji: "🚇",
    label: "打工人通勤包",
    category: "交通",
    desc: "比如：输入 ¥2，自动备注“日常地铁通勤出行”",
    rules: [
      { max: 5, notes: ["日常地铁通勤出行", "公交短途出行打卡", "选择绿色出行，简单省心"] },
      { max: 15, notes: ["公交短途出行打卡", "日常地铁通勤出行", "选择绿色出行，简单省心"] },
      { max: 30, notes: ["选择绿色出行，简单省心", "日常地铁通勤出行", "公交短途出行打卡"] },
      { max: 9999, notes: ["日常地铁通勤出行", "选择绿色出行，简单省心", "公交短途出行打卡"] },
    ],
  },
  {
    id: "food",
    emoji: "🍵",
    label: "吃货专属包",
    category: "餐饮",
    desc: "比如：输入 ¥12，自动备注“晨间咖啡唤醒日常”",
    rules: [
      { max: 15, notes: ["晨间咖啡唤醒日常", "简单饮品放松心情", "随手添置早餐小食"] },
      { max: 25, notes: ["简单饮品放松心情", "随手添置早餐小食", "晨间咖啡唤醒日常"] },
      { max: 40, notes: ["随手添置早餐小食", "简单饮品放松心情", "晨间咖啡唤醒日常"] },
      { max: 9999, notes: ["简单饮品放松心情", "随手添置早餐小食", "晨间咖啡唤醒日常"] },
    ],
  },
  {
    id: "travel",
    emoji: "✈️",
    label: "旅行预算包",
    category: "其他",
    desc: "比如：输入 ¥20，自动备注“短途出行小消费”",
    rules: [
      { max: 20, notes: ["短途出行小消费", "沿途小吃简单打卡", "出行便携物资采购"] },
      { max: 80, notes: ["沿途小吃简单打卡", "短途出行小消费", "出行便携物资采购"] },
      { max: 200, notes: ["出行便携物资采购", "短途出行小消费", "沿途小吃简单打卡"] },
      { max: 9999, notes: ["短途出行小消费", "出行便携物资采购", "沿途小吃简单打卡"] },
    ],
  },
  {
    id: "pet",
    emoji: "🐱",
    label: "铲屎官宠物包",
    category: "日用",
    desc: "比如：输入 ¥20，自动备注“给{petName}买了小零食”",
    rules: [
      { max: 20, notes: ["给{petName}买了小零食", "给{petName}安排美味小点心", "补货宠物消耗小用品"] },
      { max: 60, notes: ["为{petName}购置口粮用品", "给{petName}囤上爱吃的罐头", "入手小玩具，陪伴{petName}玩耍"] },
      { max: 150, notes: ["购入{petName}专用主食与冻干", "安排{petName}日常驱虫护理", "带{petName}洗护美容，清爽干净"] },
      { max: 9999, notes: ["带{petName}体检接种疫苗", "添置居家小窝与攀爬家具", "{petName}就医护理相关开销", "为{petName}选购高端营养口粮"] },
    ],
  },
];
const INSIGHT_BTN_IDLE_TEXT = "换一条更适合我的建议";
const INSIGHT_BTN_LOADING_TEXT = "正在为你换一条…";
const CATEGORY_AI_ENDPOINT = "http://localhost:8787/v1/category/recommend";
const PET_HIDE_SESSION_KEY = "qingzhang_pet_hidden_session";
const PET_FIRST_GUIDE_KEY = "qingzhang_pet_first_guide_shown_v1";
const WEATHER_HINT_COOLDOWN_KEY = "qingzhang_weather_hint_cooldown_v1";
const petCopy = {
  companion: [
    "我在这儿陪你，一起把钱花明白。",
    "每一笔记录，都是在帮未来的你减压，{petName}一直在。",
    "慢慢来，记账不是为了苛责自己，而是更了解自己。",
    "不想被打扰的话，长按我就能把我藏起来啦。",
  ],
  recordSaved: [
    "记下来的每一笔，都是你的掌控感呀！{petName}为你点赞～",
    "今天也按时记账啦，你超棒的！",
    "这笔记录得很好，继续保持这个节奏～",
    "今天的小快乐，也被好好记下来了。",
  ],
  lightScene: ["今天的奶茶 / 咖啡，也记得记录一下哦～", "偶尔的小快乐，也要好好记下来呀。"],
  weatherHint: [
    "如果开启定位，我可以根据天气陪你说悄悄话，治愈感满满哦～",
    "允许获取天气后，我会更懂你的小日常✨",
    "天冷、降温、下雨天，我都可以温柔提醒你，要不要浅浅授权一下？（前往设置开启）",
  ],
  weatherContext: {
    coldDrink: "今天外面有点冷，你这杯热饮刚好暖到了自己。小小花费，是给自己的温柔，不用焦虑。",
    weekendRelax: "难得的周末放松一下，这笔快乐消费很值得，你值得好好奖励自己。",
    lateNightSnack: "忙了一天，深夜的小奖励很正常。偶尔的小放松，不需要苛责自己。",
  },
  aiReview: [
    "复盘完啦，你这个月的消费节奏很稳！",
    "分析完啦，你比上个月更了解自己的钱了呢～",
    "别担心，复盘不是为了批评你，而是为了让你花得更轻松。",
    "数据不会骗你，但也别苛责自己，保持这个节奏就很好。",
  ],
  streak: ["已经坚持 {days} 天啦，你离目标越来越近了！", "连续记录 {days} 天，习惯正在长出来！"],
};
const pageTitles = {
  home: "首页",
  record: "记账",
  stats: "账单",
  insight: "AI 复盘",
  settings: "设置",
};

const defaultState = {
  settings: {
    displayName: "轻账用户",
    appearance: "system",
    syncEnabled: false,
    remoteAIEnabled: false,
    isMember: false,
    isLoggedIn: false,
    userPetNickname: "",
    petCompanionEnabled: true,
    weatherCompanionEnabled: false,
  },
  recordMode: "manual",
  period: "week",
  items: [],
  insights: [],
  monthlyInsights: [],
  monthlyTrialUsed: 0,
  isGeneratingInsight: false,
  isGeneratingMonthlyInsight: false,
};

const refs = {
  todayText: document.getElementById("todayText"),
  pageTitle: document.getElementById("pageTitle"),
  toast: document.getElementById("toast"),
  pages: {
    home: document.getElementById("homePage"),
    record: document.getElementById("recordPage"),
    stats: document.getElementById("statsPage"),
    insight: document.getElementById("insightPage"),
    settings: document.getElementById("settingsPage"),
  },
  tabs: [...document.querySelectorAll(".tab")],
  jumpButtons: [...document.querySelectorAll("[data-jump]")],
  quickManualBtn: document.getElementById("quickManualBtn"),
  todayTotal: document.getElementById("todayTotal"),
  weekTotal: document.getElementById("weekTotal"),
  homeTodayList: document.getElementById("homeTodayList"),
  homeTodayEmptyArt: document.getElementById("homeTodayEmptyArt"),
  homeInsightSummary: document.getElementById("homeInsightSummary"),
  homeInsightHint: document.getElementById("homeInsightHint"),
  dailyNudge: document.getElementById("dailyNudge"),
  petWidget: document.getElementById("petWidget"),
  petBtn: document.getElementById("petBtn"),
  petBubble: document.getElementById("petBubble"),
  petCompanionSwitch: document.getElementById("petCompanionSwitch"),
  weatherCompanionRow: document.getElementById("weatherCompanionRow"),
  weatherCompanionSwitch: document.getElementById("weatherCompanionSwitch"),
  weatherCompanionHelper: document.getElementById("weatherCompanionHelper"),
  recordModeSegment: document.getElementById("recordModeSegment"),
  modeButtons: [...document.querySelectorAll(".mode-btn")],
  manualForm: document.getElementById("manualForm"),
  ocrForm: document.getElementById("ocrForm"),
  recordFormTitle: document.getElementById("recordFormTitle"),
  amountInput: document.getElementById("amountInput"),
  amountDisplay: document.getElementById("amountDisplay"),
  amountAssist: document.getElementById("amountAssist"),
  categoryField: document.getElementById("categoryField"),
  titleInput: document.getElementById("titleInput"),
  noteSuggestions: document.getElementById("noteSuggestions"),
  noteField: document.getElementById("noteField"),
  memberScenePackBlock: document.getElementById("memberScenePackBlock"),
  memberScenePackEntryBtn: document.getElementById("memberScenePackEntryBtn"),
  memberScenePackHint: document.getElementById("memberScenePackHint"),
  memberScenePackList: document.getElementById("memberScenePackList"),
  networkHint: document.getElementById("networkHint"),
  categoryOptions: document.getElementById("categoryOptions"),
  recordDateInput: document.getElementById("recordDateInput"),
  dateHint: document.getElementById("dateHint"),
  localPrivacyHint: document.getElementById("localPrivacyHint"),
  editDateBtn: document.getElementById("editDateBtn"),
  saveRecordBtn: document.getElementById("saveRecordBtn"),
  deleteRecordBtn: document.getElementById("deleteRecordBtn"),
  ocrImageInput: document.getElementById("ocrImageInput"),
  ocrPickImageBtn: document.getElementById("ocrPickImageBtn"),
  ocrLoadingBox: document.getElementById("ocrLoadingBox"),
  ocrProgressBar: document.getElementById("ocrProgressBar"),
  ocrConfirmOverlay: document.getElementById("ocrConfirmOverlay"),
  ocrConfirmList: document.getElementById("ocrConfirmList"),
  ocrStatsCount: document.getElementById("ocrStatsCount"),
  ocrStatsAmount: document.getElementById("ocrStatsAmount"),
  ocrSelectAllBtn: document.getElementById("ocrSelectAllBtn"),
  ocrInvertBtn: document.getElementById("ocrInvertBtn"),
  ocrBatchCategorySelect: document.getElementById("ocrBatchCategorySelect"),
  ocrCancelBtn: document.getElementById("ocrCancelBtn"),
  ocrConfirmBtn: document.getElementById("ocrConfirmBtn"),
  ocrConfirmMeta: document.getElementById("ocrConfirmMeta"),
  ocrDraftSummary: document.getElementById("ocrDraftSummary"),
  ocrDraftGroups: document.getElementById("ocrDraftGroups"),
  ocrClearResolvedBtn: document.getElementById("ocrClearResolvedBtn"),
  ocrCategoryOverlay: document.getElementById("ocrCategoryOverlay"),
  ocrCategoryOptions: document.getElementById("ocrCategoryOptions"),
  billDateFilter: document.getElementById("billDateFilter"),
  billCategoryFilter: document.getElementById("billCategoryFilter"),
  billExpenseTotal: document.getElementById("billExpenseTotal"),
  billRecordsList: document.getElementById("billRecordsList"),
  billRecordsEmpty: document.getElementById("billRecordsEmpty"),
  billTrendLine: document.getElementById("billTrendLine"),
  billTrendMaxLabel: document.getElementById("billTrendMaxLabel"),
  billTrendPeakDot: document.getElementById("billTrendPeakDot"),
  billTrendPeakLabel: document.getElementById("billTrendPeakLabel"),
  billTrendInsight: document.getElementById("billTrendInsight"),
  monthlyTrialText: document.getElementById("monthlyTrialText"),
  generateMonthlyInsightBtn: document.getElementById("generateMonthlyInsightBtn"),
  monthlyInsightContent: document.getElementById("monthlyInsightContent"),
  monthlyInsightSummary: document.getElementById("monthlyInsightSummary"),
  monthlyInsightStructure: document.getElementById("monthlyInsightStructure"),
  monthlyInsightAdvice: document.getElementById("monthlyInsightAdvice"),
  monthlyTrialModal: document.getElementById("monthlyTrialModal"),
  monthlyTrialModalTitle: document.getElementById("monthlyTrialModalTitle"),
  monthlyTrialModalBody: document.getElementById("monthlyTrialModalBody"),
  monthlyTrialModalOkBtn: document.getElementById("monthlyTrialModalOkBtn"),
  monthlyTrialUpgradeBtn: document.getElementById("monthlyTrialUpgradeBtn"),
  generateQuarterlyInsightBtn: document.getElementById("generateQuarterlyInsightBtn"),
  generateYearlyInsightBtn: document.getElementById("generateYearlyInsightBtn"),
  insightSummary: document.getElementById("insightSummary"),
  insightAction: document.getElementById("insightAction"),
  insightEncourage: document.getElementById("insightEncourage"),
  insightHistory: document.getElementById("insightHistory"),
  insightHistoryEmpty: document.getElementById("insightHistoryEmpty"),
  generateInsightBtn: document.getElementById("generateInsightBtn"),
  accountEntryBtn: document.getElementById("accountEntryBtn"),
  accountAvatar: document.getElementById("accountAvatar"),
  accountEntryText: document.getElementById("accountEntryText"),
  accountOverlay: document.getElementById("accountOverlay"),
  accountCloseBtn: document.getElementById("accountCloseBtn"),
  accountLoginView: document.getElementById("accountLoginView"),
  accountCenterView: document.getElementById("accountCenterView"),
  accountSkipBtn: document.getElementById("accountSkipBtn"),
  accountPhoneLoginBtn: document.getElementById("accountPhoneLoginBtn"),
  accountWechatLoginBtn: document.getElementById("accountWechatLoginBtn"),
  accountCenterAvatar: document.getElementById("accountCenterAvatar"),
  accountCenterName: document.getElementById("accountCenterName"),
  accountCenterState: document.getElementById("accountCenterState"),
  accountPetNicknameInput: document.getElementById("accountPetNicknameInput"),
  accountPetNicknameSaveBtn: document.getElementById("accountPetNicknameSaveBtn"),
  accountPetNicknameTip: document.getElementById("accountPetNicknameTip"),
  accountUpgradeEntryBtn: document.getElementById("accountUpgradeEntryBtn"),
  accountMemberView: document.getElementById("accountMemberView"),
  accountMemberBackBtn: document.getElementById("accountMemberBackBtn"),
  buyMonthlyBtn: document.getElementById("buyMonthlyBtn"),
  buyYearlyBtn: document.getElementById("buyYearlyBtn"),
  buyLifetimeBtn: document.getElementById("buyLifetimeBtn"),
  accountBindPhoneBtn: document.getElementById("accountBindPhoneBtn"),
  accountLogoutBtn: document.getElementById("accountLogoutBtn"),
  displayNameInput: document.getElementById("displayNameInput"),
  syncSwitch: document.getElementById("syncSwitch"),
  remoteAISwitch: document.getElementById("remoteAISwitch"),
  resetGuideBtn: document.getElementById("resetGuideBtn"),
  appearanceButtons: [...document.querySelectorAll(".appearance-btn")],
  guideOverlay: document.getElementById("guideOverlay"),
  guideStepText: document.getElementById("guideStepText"),
  guideTitle: document.getElementById("guideTitle"),
  guideDesc: document.getElementById("guideDesc"),
  guideSkipBtn: document.getElementById("guideSkipBtn"),
  guideNextBtn: document.getElementById("guideNextBtn"),
};

const state = loadState();
const systemThemeQuery = window.matchMedia("(prefers-color-scheme: dark)");
let guideStep = 1;
let selectedCategory = null;
let categoryLockedByUser = false;
let categoryRecommendRequestId = 0;
let pulseCategoryValue = null;
const categoryButtonMap = new Map();
let amountStream = { intPart: "", decPart: "", hasDot: false };
let isAmountInputFocused = false;
let ocrProgressTimer = null;
let ocrDraftRecords = [];
let editingDraftItemId = null;
let editingRecordId = null;
let petBubbleTimer = null;
let currentTab = "home";
let petPressTimer = null;
let petLongPressTriggered = false;
let pendingPetBubbleText = "";
let weatherGeo = null;
let weatherSnapshot = null;
let isRequestingWeatherPermission = false;
let accountOverlayView = "login";

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return structuredClone(defaultState);
    const parsed = JSON.parse(raw);
    return {
      ...structuredClone(defaultState),
      ...parsed,
      settings: { ...defaultState.settings, ...parsed.settings },
      items: Array.isArray(parsed.items) ? parsed.items : [],
      insights: Array.isArray(parsed.insights) ? parsed.insights : [],
    };
  } catch {
    return structuredClone(defaultState);
  }
}

function persist() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function showToast(message) {
  refs.toast.textContent = message;
  refs.toast.classList.remove("hidden");
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => {
    refs.toast.classList.add("hidden");
  }, 1600);
}

function applyTheme() {
  document.body.classList.remove("theme-dark");
  const mode = state.settings.appearance;
  if (mode === "dark") document.body.classList.add("theme-dark");
  if (mode === "system" && systemThemeQuery.matches) document.body.classList.add("theme-dark");
  refs.appearanceButtons.forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.appearance === mode);
  });
}

function switchTab(tab) {
  currentTab = tab;
  Object.keys(refs.pages).forEach((key) => refs.pages[key].classList.toggle("active", key === tab));
  refs.tabs.forEach((btn) => btn.classList.toggle("active", btn.dataset.tab === tab));
  refs.pageTitle.textContent = pageTitles[tab];
  if (tab === "settings") {
    renderSettings();
  }
  updatePetVisibility();
  if (tab === "home" && pendingPetBubbleText) {
    const text = pendingPetBubbleText;
    pendingPetBubbleText = "";
    setTimeout(() => showPetBubble(text), 120);
  }
  if (tab === "record") {
    setTimeout(() => {
      refs.amountInput?.focus();
    }, 40);
  }
}

function isPetTemporarilyHidden() {
  return sessionStorage.getItem(PET_HIDE_SESSION_KEY) === "1";
}

function updatePetVisibility() {
  const shouldShow = currentTab === "home" && state.settings.petCompanionEnabled && !isPetTemporarilyHidden();
  refs.petWidget.classList.toggle("hidden", !shouldShow);
  if (shouldShow) {
    refs.petWidget.classList.remove("pet-hiding");
  }
  if (!shouldShow) {
    refs.petBubble.classList.add("hidden");
  }
}

function pickRandom(list) {
  return list[Math.floor(Math.random() * list.length)];
}

function showPetBubble(text) {
  if (!state.settings.petCompanionEnabled || isPetTemporarilyHidden()) return;
  if (currentTab !== "home") {
    pendingPetBubbleText = text || "";
    return;
  }
  if (!text) return;
  refs.petBubble.textContent = personalizePetText(text);
  refs.petBubble.classList.remove("hidden");
  clearTimeout(petBubbleTimer);
  petBubbleTimer = setTimeout(() => {
    refs.petBubble.classList.add("hidden");
  }, 2600);
}

function showPetFirstGuideOnce() {
  if (localStorage.getItem(PET_FIRST_GUIDE_KEY)) return;
  if (!state.settings.petCompanionEnabled || isPetTemporarilyHidden() || currentTab !== "home") return;
  showPetBubble("我会一直在这儿陪你。长按我，就能暂时把{petName}藏起来哦~");
  localStorage.setItem(PET_FIRST_GUIDE_KEY, "1");
}

function consecutiveRecordDays() {
  const daySet = new Set(state.items.map((x) => x.createdAt.slice(0, 10)));
  let days = 0;
  const cursor = new Date();
  while (true) {
    const key = cursor.toISOString().slice(0, 10);
    if (!daySet.has(key)) break;
    days += 1;
    cursor.setDate(cursor.getDate() - 1);
  }
  return days;
}

function shouldNudgeWeather() {
  const now = Date.now();
  const last = Number(localStorage.getItem(WEATHER_HINT_COOLDOWN_KEY) || "0");
  if (now - last < 1000 * 60 * 60 * 20) return false;
  localStorage.setItem(WEATHER_HINT_COOLDOWN_KEY, String(now));
  return true;
}

function isWeekend(dateText) {
  const d = new Date(dateText || Date.now());
  const day = d.getDay();
  return day === 0 || day === 6;
}

function isLateNight(dateText) {
  const d = new Date(dateText || Date.now());
  const h = d.getHours();
  return h >= 22 || h <= 3;
}

function isDrinkOrSnack(recordLike) {
  const text = `${recordLike.title || ""} ${recordLike.category || ""}`.toLowerCase();
  return /(奶茶|咖啡|饮品|热饮|宵夜|零食|甜品)/.test(text);
}

async function fetchWeatherSnapshot() {
  if (!weatherGeo) return null;
  const now = Date.now();
  if (weatherSnapshot && now - weatherSnapshot.ts < 1000 * 60 * 30) {
    return weatherSnapshot;
  }
  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${weatherGeo.lat}&longitude=${weatherGeo.lon}&current=temperature_2m,weather_code`;
    const resp = await fetch(url);
    if (!resp.ok) return null;
    const data = await resp.json();
    weatherSnapshot = {
      ts: now,
      temp: Number(data?.current?.temperature_2m),
      weatherCode: Number(data?.current?.weather_code),
    };
    return weatherSnapshot;
  } catch {
    return null;
  }
}

async function buildContextualPetMessage(recordLike) {
  if (!state.settings.weatherCompanionEnabled) {
    if (isDrinkOrSnack(recordLike) && shouldNudgeWeather()) {
      return pickRandom(petCopy.weatherHint);
    }
    return pickRandom(petCopy.recordSaved);
  }
  const weather = await fetchWeatherSnapshot();
  if (weather?.temp <= 12 && isDrinkOrSnack(recordLike)) {
    return petCopy.weatherContext.coldDrink;
  }
  if (isWeekend(recordLike.createdAt) && /(娱乐|餐饮)/.test(recordLike.category || "")) {
    return petCopy.weatherContext.weekendRelax;
  }
  if (isLateNight(recordLike.createdAt) && isDrinkOrSnack(recordLike)) {
    return petCopy.weatherContext.lateNightSnack;
  }
  return pickRandom(petCopy.recordSaved);
}

function buildAiReviewPetMessage() {
  if (!state.settings.weatherCompanionEnabled && Math.random() < 0.25 && shouldNudgeWeather()) {
    return "若开启天气权限，后续 AI 复盘会结合季节给你更贴合的温柔建议～（前往设置开启）";
  }
  return pickRandom(petCopy.aiReview);
}

async function requestWeatherPermissionFlow() {
  if (typeof navigator === "undefined" || !navigator.geolocation) {
    showToast("当前环境不支持定位权限");
    return false;
  }
  return new Promise((resolve) => {
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        weatherGeo = { lat: pos.coords.latitude, lon: pos.coords.longitude };
        resolve(true);
      },
      () => resolve(false),
      { timeout: 5000, maximumAge: 1000 * 60 * 30 }
    );
  });
}

function sameMonth(date) {
  const d = new Date(date);
  const now = new Date();
  return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
}

function sameWeek(date) {
  const d = new Date(date);
  const now = new Date();
  const first = new Date(now);
  first.setDate(now.getDate() - ((now.getDay() + 6) % 7));
  first.setHours(0, 0, 0, 0);
  const last = new Date(first);
  last.setDate(first.getDate() + 7);
  return d >= first && d < last;
}

function sameYear(date) {
  const d = new Date(date);
  const now = new Date();
  return d.getFullYear() === now.getFullYear();
}

function formatCNY(value) {
  return value.toLocaleString("zh-CN", { style: "currency", currency: "CNY" });
}

function isAmountReady() {
  return getAmountValue() > 0;
}

function getAmountValue() {
  const amount = Number.parseFloat(refs.amountInput?.value || "0");
  if (Number.isNaN(amount)) return 0;
  return amount;
}

function hasAmountStreamValue(stream = amountStream) {
  return Boolean(stream.intPart || stream.decPart || stream.hasDot);
}

function normalizeIntPart(intPart) {
  const digits = (intPart || "").replace(/\D/g, "");
  if (!digits) return "";
  const trimmed = digits.replace(/^0+(?=\d)/, "");
  return trimmed || "0";
}

function parseAmountTextToStream(text) {
  const normalized = (text || "").replace(/[^\d.]/g, "");
  if (!normalized) {
    return { intPart: "", decPart: "", hasDot: false };
  }
  const hasDot = normalized.includes(".");
  const [rawInt = "", rawDec = ""] = normalized.split(".");
  const intPart = normalizeIntPart(rawInt);
  const decPart = rawDec.replace(/\./g, "").slice(0, 2);
  if (!intPart && !decPart && !hasDot) {
    return { intPart: "", decPart: "", hasDot: false };
  }
  return {
    intPart: intPart || (hasDot ? "0" : ""),
    decPart,
    hasDot,
  };
}

function formatStreamAmount(stream = amountStream) {
  if (!hasAmountStreamValue(stream)) return "";
  const intPart = stream.intPart || "0";
  const decPart = (stream.decPart + "00").slice(0, 2);
  return `${intPart}.${decPart}`;
}

function updateAmountInputFromStream() {
  refs.amountInput.value = formatStreamAmount();
  renderAmountDisplay();
}

function appendDisplayPart(fragment, isGhost = false, extraClass = "") {
  if (!fragment) return;
  const span = document.createElement("span");
  if (isGhost) span.classList.add("ghost");
  if (extraClass) span.classList.add(extraClass);
  span.textContent = fragment;
  refs.amountDisplay.appendChild(span);
}

function renderAmountDisplay() {
  if (!refs.amountDisplay) return;
  refs.amountDisplay.innerHTML = "";
  refs.amountDisplay.classList.remove("placeholder");

  if (!hasAmountStreamValue()) {
    refs.amountDisplay.classList.add("placeholder");
    refs.amountDisplay.textContent = "¥0.00";
    return;
  }

  const intPart = amountStream.intPart || "0";
  const typedDecPart = amountStream.decPart || "";
  const filledDecPart = (typedDecPart + "00").slice(0, 2);
  const autoDecPart = filledDecPart.slice(typedDecPart.length);
  const allSolid = !isAmountInputFocused;

  appendDisplayPart("¥", !allSolid, "currency");
  appendDisplayPart(intPart, false);
  if (allSolid) {
    appendDisplayPart(`.${filledDecPart}`, false);
    return;
  }

  if (!amountStream.hasDot && typedDecPart.length === 0) {
    appendDisplayPart(".00", true);
    return;
  }

  appendDisplayPart(".", false);
  appendDisplayPart(typedDecPart, false);
  appendDisplayPart(autoDecPart, true);
}

function syncAmountUIAfterInput({ shouldRecommend = true } = {}) {
  updateAmountInputFromStream();
  renderRecord();
  if (shouldRecommend && isAmountReady()) {
    scheduleCategoryRecommendation();
  }
}

function appendAmountDigit(digit) {
  if (amountStream.hasDot) {
    if (amountStream.decPart.length < 2) {
      amountStream.decPart += digit;
    }
    return;
  }
  const base = amountStream.intPart || "";
  amountStream.intPart = normalizeIntPart(`${base}${digit}`);
}

function removeAmountDigit() {
  if (!hasAmountStreamValue()) return;
  if (amountStream.hasDot && amountStream.decPart.length > 0) {
    amountStream.decPart = amountStream.decPart.slice(0, -1);
    return;
  }
  if (amountStream.hasDot) {
    amountStream.hasDot = false;
    return;
  }
  amountStream.intPart = amountStream.intPart.slice(0, -1);
}

function handleAmountInputKeydown(event) {
  if (event.ctrlKey || event.metaKey || event.altKey) return;
  const { key } = event;
  if (/^\d$/.test(key)) {
    appendAmountDigit(key);
    event.preventDefault();
    syncAmountUIAfterInput();
    return;
  }
  if (key === ".") {
    amountStream.hasDot = true;
    if (!amountStream.intPart) {
      amountStream.intPart = "0";
    }
    event.preventDefault();
    syncAmountUIAfterInput({ shouldRecommend: false });
    return;
  }
  if (key === "Backspace") {
    removeAmountDigit();
    if (!hasAmountStreamValue()) {
      amountStream = { intPart: "", decPart: "", hasDot: false };
    }
    event.preventDefault();
    syncAmountUIAfterInput();
    return;
  }
  if (key === "Delete") {
    amountStream = { intPart: "", decPart: "", hasDot: false };
    event.preventDefault();
    syncAmountUIAfterInput({ shouldRecommend: false });
  }
}

function getCategoryMeta(value) {
  return categories.find((x) => x.value === value) || categories[categories.length - 1];
}

function updateNotePlaceholder() {
  const amountReady = isAmountReady();
  if (!amountReady) {
    refs.titleInput.placeholder = "已自动归类，可补充点细节（不填也能保存）";
    return;
  }
  const meta = getCategoryMeta(selectedCategory || localRecommendedCategory());
  refs.titleInput.placeholder = `已归类到「${meta.label}」，可补充点细节（不填也能保存）`;
}

function updateCategoryUI() {
  if (!selectedCategory) {
    renderCategoryOptions();
    updateNotePlaceholder();
    return;
  }
  renderCategoryOptions();
  updateNotePlaceholder();
}

function topCategoryFromHistory() {
  if (!state.items.length) return "餐饮";
  const map = {};
  state.items.forEach((item) => {
    map[item.category] = (map[item.category] || 0) + 1;
  });
  return Object.entries(map).sort((a, b) => b[1] - a[1])[0]?.[0] || "餐饮";
}

function localRecommendedCategory() {
  const amount = getAmountValue();
  if (Number.isNaN(amount) || amount <= 0) return topCategoryFromHistory() || "餐饮";
  if (amount >= 100) return "购物";
  if (amount > 0 && amount <= 20) return "餐饮";
  if (amount > 20 && amount < 50) return "交通";
  if (amount === 50) return "其他";
  return topCategoryFromHistory() || "餐饮";
}

async function recommendCategorySmart() {
  const local = localRecommendedCategory();
  if (!state.settings.remoteAIEnabled || categoryLockedByUser) {
    return { category: local, source: "local" };
  }

  const amount = getAmountValue();
  if (Number.isNaN(amount) || amount <= 0) {
    return { category: local, source: "local" };
  }

  const note = refs.titleInput.value.trim();
  const prompt = `根据金额与备注推荐消费分类，只返回一个分类：餐饮/购物/交通/娱乐/日用/其他。金额：${amount}，备注：${note || "无"}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 1800);
  try {
    const response = await fetch(CATEGORY_AI_ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: "glm-4-flash",
        messages: [
          { role: "system", content: "你是消费分类助手，只返回一个分类词，不解释。" },
          { role: "user", content: prompt },
        ],
        temperature: 0.1,
      }),
      signal: controller.signal,
    });
    clearTimeout(timer);
    if (!response.ok) {
      return { category: local, source: "local" };
    }
    const data = await response.json();
    const text = extractCategoryText(data);
    const mapped = mapCategoryFromText(text);
    return { category: mapped || local, source: mapped ? "ai" : "local" };
  } catch (_error) {
    clearTimeout(timer);
    return { category: local, source: "local" };
  }
}

function extractCategoryText(data) {
  if (typeof data?.category === "string") return data.category;
  if (typeof data?.result === "string") return data.result;
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content === "string") return content;
  return "";
}

function mapCategoryFromText(text) {
  const normalized = text.replace(/\s/g, "");
  const categoryValues = categories.map((x) => x.value);
  return categoryValues.find((value) => normalized.includes(value)) || null;
}

function renderCategoryOptions() {
  const isEditing = Boolean(editingRecordId);
  if (!isAmountReady() && !isEditing) {
    refs.categoryOptions.innerHTML = "";
    categoryButtonMap.clear();
    return;
  }
  const recommended = isEditing ? selectedCategory || topCategoryFromHistory() : localRecommendedCategory();
  const shouldShowRecommendedTag = !isEditing && !(categoryLockedByUser && selectedCategory && selectedCategory !== recommended);
  // Keep "recommended" as default, but never override an explicit user pick.
  if (!selectedCategory) {
    selectedCategory = recommended || categories[0]?.value || "其他";
  }
  categories.forEach((item) => {
    let button = categoryButtonMap.get(item.value);
    if (!button) {
      button = document.createElement("button");
      button.type = "button";
      button.className = "category-chip";
      button.textContent = `${item.icon} ${item.label}`;
      button.addEventListener("click", () => {
        selectCategory(item.value);
        button.classList.remove("just-selected");
        requestAnimationFrame(() => {
          button.classList.add("just-selected");
        });
      });
      categoryButtonMap.set(item.value, button);
      refs.categoryOptions.appendChild(button);
    }
    button.classList.toggle("active", item.value === selectedCategory);
    button.classList.toggle("recommended", shouldShowRecommendedTag && item.value === recommended);
    button.classList.toggle("pulse-recommend", item.value === pulseCategoryValue);
  });
  if (pulseCategoryValue) {
    setTimeout(() => {
      pulseCategoryValue = null;
    }, 260);
  }
}

function likelyCategoryValues(amount, recommended) {
  let values;
  if (amount <= 20) {
    values = ["餐饮", "交通", "日用", "其他"];
  } else if (amount <= 50) {
    values = ["交通", "餐饮", "日用", "其他"];
  } else if (amount < 100) {
    values = ["日用", "交通", "娱乐", "其他"];
  } else {
    values = ["购物", "日用", "娱乐", "其他"];
  }
  if (recommended && !values.includes(recommended)) {
    values[0] = recommended;
  }
  return values;
}

function selectCategory(value) {
  selectedCategory = value;
  categoryLockedByUser = true;
  triggerHaptic();
  updateCategoryUI();
}

function renderNoteSuggestions() {
  const input = refs.titleInput.value.trim();
  const key = input.slice(0, 1);
  const baseSuggestions = noteSuggestionMap[key] || [];
  const historySuggestions = getHistoryNoteSuggestions(input);
  const suggestions = dedupe([...historySuggestions, ...baseSuggestions]).slice(0, 4);
  if (!input || suggestions.length === 0) {
    refs.noteSuggestions.classList.add("hidden");
    refs.noteSuggestions.innerHTML = "";
    return;
  }

  refs.noteSuggestions.innerHTML = "";
  suggestions.forEach((text) => {
    const chip = document.createElement("button");
    chip.type = "button";
    chip.className = "category-chip note-chip";
    chip.textContent = text;
    chip.addEventListener("click", () => {
      refs.titleInput.value = text;
      refs.noteSuggestions.classList.add("hidden");
      refs.noteSuggestions.innerHTML = "";
      refs.titleInput.focus();
    });
    refs.noteSuggestions.appendChild(chip);
  });
  refs.noteSuggestions.classList.remove("hidden");
}

function resolvePetNameForNote() {
  const raw = (state.settings.userPetNickname || "").trim();
  const isMember = Boolean(state.settings.isMember);
  if (isMember && /^[\u4e00-\u9fa5A-Za-z0-9]{2,6}$/.test(raw)) return raw;
  return "小宠物";
}

function personalizePetText(text) {
  if (!text) return "";
  return String(text).replace(/\{petName\}/g, resolvePetNameForNote());
}

function pickHistoryKeyword(category) {
  const keywords = state.items
    .filter((item) => item.category === category)
    .map((item) => (item.title || "").trim())
    .filter((text) => text && !/消费$/.test(text) && text.length >= 2 && text.length <= 8);
  if (!keywords.length) return "";
  return pickRandom(keywords.slice(0, 10));
}

function enrichNoteWithHistory(note, category) {
  const keyword = pickHistoryKeyword(category);
  if (!keyword) return note;
  if (note.includes(keyword)) return note;
  if (Math.random() > 0.45) return note;
  return `${note}，顺带记下「${keyword}」`;
}

function applyMemberScenePack(packId) {
  const pack = memberScenePacks.find((x) => x.id === packId);
  if (!pack) return;
  const amount = getAmountValue();
  const matchedRule = pack.rules.find((rule) => amount <= rule.max) || pack.rules[pack.rules.length - 1];
  const petName = resolvePetNameForNote();
  let phrase = pickRandom(matchedRule?.notes || ["今天记一笔日常花费"]);
  phrase = phrase.replace(/\{petName\}/g, petName);
  phrase = enrichNoteWithHistory(phrase, pack.category);
  selectCategory(pack.category);
  refs.titleInput.value = phrase;
  refs.noteSuggestions.classList.add("hidden");
  refs.noteSuggestions.innerHTML = "";
  renderRecord();
  showToast(`已生成：${pack.label}`);
}

function renderMemberScenePacks() {
  const isManualMode = state.recordMode === "manual";
  const isEditing = Boolean(editingRecordId);
  const amountReady = isAmountReady();
  const isMember = Boolean(state.settings.isMember);
  const shouldShow = isManualMode && !isEditing && amountReady && isMember;
  refs.memberScenePackBlock.classList.toggle("hidden", !shouldShow);
  if (!shouldShow) return;

  refs.memberScenePackEntryBtn.classList.add("hidden");
  refs.memberScenePackHint.textContent = "小宠物的记账小帮手：选个场景，我帮你猜今天花在哪，自动填好备注。";
  refs.memberScenePackList.innerHTML = "";
  memberScenePacks.forEach((pack) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "scene-pack-chip";
    const preview = pack.desc.replace(/\{petName\}/g, resolvePetNameForNote());
    btn.innerHTML = `${pack.emoji} ${pack.label}<small>${preview}</small>`;
    btn.addEventListener("click", () => applyMemberScenePack(pack.id));
    refs.memberScenePackList.appendChild(btn);
  });
}

function getHistoryNoteSuggestions(prefix) {
  if (!prefix) return [];
  const hitCount = new Map();
  for (const item of state.items) {
    const title = (item.title || "").trim();
    if (!title || /消费$/.test(title)) continue;
    if (!title.startsWith(prefix)) continue;
    hitCount.set(title, (hitCount.get(title) || 0) + 1);
  }
  return [...hitCount.entries()]
    .sort((a, b) => b[1] - a[1])
    .map(([title]) => title)
    .slice(0, 5);
}

function dedupe(list) {
  const seen = new Set();
  return list.filter((item) => {
    if (!item || seen.has(item)) return false;
    seen.add(item);
    return true;
  });
}

function addRecord({ title, amount, category, source, occurredAt }) {
  if (!amount || Number.isNaN(amount) || amount <= 0) {
    showToast("请先填写有效金额。");
    return false;
  }
  const finalCategory = category || "其他";
  const finalTitle = title && title.trim() ? title.trim() : `${finalCategory}消费`;
  const finalDate = occurredAt ? mergeDateWithCurrentTime(occurredAt) : new Date().toISOString();
  state.items.unshift({
    id: crypto.randomUUID(),
    title: finalTitle,
    amount: Number(amount),
    category: finalCategory,
    source,
    createdAt: finalDate,
  });
  persist();
  render();
  triggerHaptic();
  return true;
}

function setOCRLoading(loading, progress = 0) {
  refs.ocrLoadingBox.classList.toggle("hidden", !loading);
  refs.ocrPickImageBtn.disabled = loading;
  refs.ocrProgressBar.style.width = `${Math.max(0, Math.min(100, progress))}%`;
}

function parseBillRowsFromFilename(filename) {
  const normalized = (filename || "").toLowerCase();
  if (normalized.includes("wechat") || normalized.includes("wx") || normalized.includes("微信")) {
    return [
      { title: "微信支付-便利店", amount: 18.8, category: "日用" },
      { title: "微信支付-午餐", amount: 26.0, category: "餐饮" },
      { title: "微信支付-地铁", amount: 4.0, category: "交通" },
    ];
  }
  if (normalized.includes("alipay") || normalized.includes("支付宝") || normalized.includes("zfb")) {
    return [
      { title: "支付宝-早餐", amount: 12.5, category: "餐饮" },
      { title: "支付宝-咖啡", amount: 19.9, category: "餐饮" },
      { title: "支付宝-日用品", amount: 38.0, category: "日用" },
    ];
  }
  return [
    { title: "账单识别-餐饮", amount: 23.5, category: "餐饮" },
    { title: "账单识别-交通", amount: 6.0, category: "交通" },
  ];
}

async function runMockOCR(file) {
  clearInterval(ocrProgressTimer);
  setOCRLoading(true, 8);
  let progress = 8;
  ocrProgressTimer = setInterval(() => {
    progress = Math.min(92, progress + Math.random() * 15);
    setOCRLoading(true, progress);
  }, 180);
  await new Promise((resolve) => setTimeout(resolve, 1300));
  clearInterval(ocrProgressTimer);
  setOCRLoading(true, 100);
  await new Promise((resolve) => setTimeout(resolve, 220));
  setOCRLoading(false, 0);
  const now = new Date().toISOString();
  return parseBillRowsFromFilename(file?.name).map((x) => ({ ...x, createdAt: now }));
}

function renderOCRConfirmList(records) {
  refs.ocrConfirmList.innerHTML = "";
  records.forEach((item, index) => {
    const li = document.createElement("li");
    li.dataset.ocrRowIndex = String(index);
    const checked = item.selected !== false ? "checked" : "";
    li.innerHTML = `
      <label class="ocr-item-check">
        <input type="checkbox" data-ocr-check-index="${index}" ${checked} />
        <span>导入此条</span>
      </label>
      <p class="ocr-item-amount">${formatCNY(item.amount)}</p>
      <p class="muted ocr-item-meta">${new Date(item.createdAt).toLocaleString()} · ${item.title}</p>
      <div class="ocr-item-category">
        <select data-ocr-index="${index}">
          ${categories
            .map((c) => `<option value="${c.value}" ${c.value === item.category ? "selected" : ""}>${c.icon} ${c.value}</option>`)
            .join("")}
        </select>
      </div>
    `;
    refs.ocrConfirmList.appendChild(li);
  });
  refs.ocrConfirmList.querySelectorAll("input[data-ocr-check-index]").forEach((checkEl) => {
    checkEl.addEventListener("change", (event) => {
      const idx = Number(event.target.dataset.ocrCheckIndex);
      ocrDraftRecords[idx].selected = event.target.checked;
      updateOCRSelectionState();
    });
  });
  refs.ocrConfirmList.querySelectorAll("select[data-ocr-index]").forEach((selectEl) => {
    selectEl.addEventListener("change", (event) => {
      const idx = Number(event.target.dataset.ocrIndex);
      ocrDraftRecords[idx].category = event.target.value;
    });
  });
}

function updateOCRSelectionState() {
  const selectedCount = ocrDraftRecords.filter((x) => x.selected !== false).length;
  refs.ocrConfirmMeta.textContent = `已选 ${selectedCount} 条`;
  refs.ocrConfirmBtn.disabled = selectedCount === 0;
  refs.ocrSelectAllBtn.textContent = selectedCount === ocrDraftRecords.length && selectedCount > 0 ? "取消全选" : "全选";
}

function animateOCRRowChanged(index) {
  const row = refs.ocrConfirmList.querySelector(`li[data-ocr-row-index="${index}"]`);
  if (!row) return;
  row.classList.remove("ocr-row-updated");
  requestAnimationFrame(() => {
    row.classList.add("ocr-row-updated");
    setTimeout(() => row.classList.remove("ocr-row-updated"), 320);
  });
}

function openOCRConfirm(records) {
  ocrDraftRecords = records.map((x) => ({ ...x, selected: true }));
  refs.ocrStatsCount.textContent = String(ocrDraftRecords.length);
  const total = ocrDraftRecords.reduce((sum, x) => sum + x.amount, 0);
  refs.ocrStatsAmount.textContent = formatCNY(total);
  renderOCRConfirmList(ocrDraftRecords);
  updateOCRSelectionState();
  refs.ocrConfirmOverlay.classList.remove("hidden");
}

function closeOCRConfirm() {
  refs.ocrConfirmOverlay.classList.add("hidden");
  refs.ocrConfirmList.innerHTML = "";
  refs.ocrBatchCategorySelect.value = "";
  refs.ocrConfirmMeta.textContent = "已选 0 条";
  ocrDraftRecords = [];
}

function importOCRRecords(records) {
  const importBatchId = `batch_${Date.now()}`;
  const importedAt = new Date().toISOString();
  const rows = records
    .filter((x) => x.selected !== false && Number(x.amount) > 0)
    .map((x) => ({
      id: crypto.randomUUID(),
      title: x.title || `${x.category || "其他"}消费`,
      amount: Number(x.amount),
      category: x.category || "其他",
      source: "ocr",
      createdAt: x.createdAt || new Date().toISOString(),
      draftMeta: {
        batchId: importBatchId,
        importedAt,
        source: x.source || "ocr",
        status: "pending",
      },
    }));
  if (!rows.length) return 0;
  state.items.unshift(...rows);
  persist();
  render();
  triggerHaptic();
  return rows.length;
}

function draftItemsByRecentBatches() {
  const draftItems = state.items.filter((x) => x.draftMeta?.batchId);
  const batchIds = [
    ...new Set(
      draftItems
        .sort((a, b) => new Date(b.draftMeta.importedAt) - new Date(a.draftMeta.importedAt))
        .map((x) => x.draftMeta.batchId)
    ),
  ].slice(0, 3);
  return draftItems.filter((x) => batchIds.includes(x.draftMeta.batchId));
}

function openDraftCategoryPicker(itemId) {
  editingDraftItemId = itemId;
  refs.ocrCategoryOptions.innerHTML = "";
  categories.forEach((category) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "category-chip";
    button.textContent = `${category.icon} ${category.value}`;
    button.addEventListener("click", () => {
      const item = state.items.find((x) => x.id === editingDraftItemId);
      if (!item) return;
      item.category = category.value;
      persist();
      render();
      closeDraftCategoryPicker();
      triggerHaptic();
    });
    refs.ocrCategoryOptions.appendChild(button);
  });
  refs.ocrCategoryOverlay.classList.remove("hidden");
}

function closeDraftCategoryPicker() {
  editingDraftItemId = null;
  refs.ocrCategoryOverlay.classList.add("hidden");
}

function toggleDraftStatus(itemId, checked) {
  const item = state.items.find((x) => x.id === itemId);
  if (!item?.draftMeta) return;
  item.draftMeta.status = checked ? "resolved" : "pending";
  persist();
  render();
}

function deleteDraftItem(itemId) {
  const index = state.items.findIndex((x) => x.id === itemId);
  if (index < 0) return;
  state.items.splice(index, 1);
  persist();
  render();
}

function updateDraftAmount(itemId, rawValue) {
  const item = state.items.find((x) => x.id === itemId);
  if (!item) return false;
  const normalized = String(rawValue || "").replace(/[^\d.]/g, "");
  const amount = Number.parseFloat(normalized);
  if (Number.isNaN(amount) || amount <= 0) {
    return false;
  }
  item.amount = Number(amount.toFixed(2));
  persist();
  render();
  return true;
}

function clearResolvedDraftMarks() {
  state.items.forEach((item) => {
    if (item.draftMeta?.status === "resolved") {
      delete item.draftMeta;
    }
  });
  persist();
  render();
}

function bindDraftSwipe(rowEl, itemId) {
  let startX = 0;
  rowEl.addEventListener("touchstart", (event) => {
    startX = event.touches[0]?.clientX || 0;
  });
  rowEl.addEventListener("touchend", (event) => {
    const endX = event.changedTouches[0]?.clientX || startX;
    const deltaX = endX - startX;
    if (deltaX < -30) {
      rowEl.classList.add("swiped");
    } else if (deltaX > 20) {
      rowEl.classList.remove("swiped");
    }
  });
  const deleteBtn = rowEl.querySelector(".ocr-draft-delete");
  deleteBtn?.addEventListener("click", () => {
    deleteDraftItem(itemId);
  });
}

function renderOCRDraftArea() {
  const items = draftItemsByRecentBatches();
  const pendingItems = items.filter((x) => x.draftMeta?.status !== "resolved");
  const total = pendingItems.reduce((sum, x) => sum + x.amount, 0);
  refs.ocrDraftSummary.textContent = `共 ${pendingItems.length} 笔待整理 · 合计 ${formatCNY(total)}`;
  refs.ocrDraftGroups.innerHTML = "";
  if (!items.length) {
    refs.ocrDraftGroups.innerHTML = `<p class="muted">导入的账单会在这里变成草稿，方便你随时整理～</p>`;
    return;
  }
  const grouped = new Map();
  items.forEach((item) => {
    const key = item.draftMeta.batchId;
    if (!grouped.has(key)) grouped.set(key, []);
    grouped.get(key).push(item);
  });
  [...grouped.entries()]
    .sort((a, b) => new Date(b[1][0].draftMeta.importedAt) - new Date(a[1][0].draftMeta.importedAt))
    .forEach(([, groupItems]) => {
      const groupWrap = document.createElement("section");
      groupWrap.className = "ocr-draft-group";
      const first = groupItems[0];
      const title = document.createElement("div");
      title.className = "ocr-draft-group-title";
      title.textContent = `${new Date(first.draftMeta.importedAt).toLocaleDateString("zh-CN")} 导入`;
      groupWrap.appendChild(title);
      groupItems.forEach((item) => {
        const row = document.createElement("div");
        row.className = `ocr-draft-row ${item.draftMeta.status === "resolved" ? "resolved" : ""}`;
        const pending = item.draftMeta.status !== "resolved";
        row.innerHTML = `
          <div class="ocr-draft-row-inner">
            <input type="checkbox" ${pending ? "" : "checked"} />
            <div class="ocr-draft-main">
              <p class="muted">${new Date(item.createdAt).toLocaleString()}</p>
              <button type="button" class="ocr-draft-category">${item.category}${pending ? '<span class="ocr-draft-pending">待整理</span>' : ""}</button>
            </div>
            <div class="ocr-draft-amount-wrap">
              <button type="button" class="ocr-draft-amount">${formatCNY(item.amount)}</button>
              <input type="text" inputmode="decimal" class="ocr-draft-amount-input hidden" value="${Number(item.amount).toFixed(2)}" />
            </div>
          </div>
          <button type="button" class="ocr-draft-delete">删除</button>
        `;
        row.querySelector("input[type='checkbox']")?.addEventListener("change", (event) => {
          toggleDraftStatus(item.id, event.target.checked);
        });
        row.querySelector(".ocr-draft-category")?.addEventListener("click", () => {
          openDraftCategoryPicker(item.id);
        });
        const amountBtn = row.querySelector(".ocr-draft-amount");
        const amountInput = row.querySelector(".ocr-draft-amount-input");
        amountBtn?.addEventListener("click", () => {
          amountBtn.classList.add("hidden");
          amountInput.classList.remove("hidden");
          amountInput.focus();
          amountInput.select();
        });
        const finishAmountEdit = (commit) => {
          if (commit) {
            const ok = updateDraftAmount(item.id, amountInput.value);
            if (!ok) {
              showToast("请输入大于 0 的金额");
            }
          } else {
            amountInput.value = Number(item.amount).toFixed(2);
            amountBtn.classList.remove("hidden");
            amountInput.classList.add("hidden");
          }
        };
        amountInput?.addEventListener("keydown", (event) => {
          if (event.key === "Enter") {
            finishAmountEdit(true);
          }
          if (event.key === "Escape") {
            finishAmountEdit(false);
          }
        });
        amountInput?.addEventListener("blur", () => {
          finishAmountEdit(true);
        });
        bindDraftSwipe(row, item.id);
        groupWrap.appendChild(row);
      });
      refs.ocrDraftGroups.appendChild(groupWrap);
    });
}

function triggerHaptic() {
  if (typeof navigator !== "undefined" && typeof navigator.vibrate === "function") {
    navigator.vibrate(12);
  }
}

function mergeDateWithCurrentTime(dateText) {
  if (!dateText) return new Date().toISOString();
  const parts = dateText.split("-").map(Number);
  if (parts.length !== 3 || parts.some((x) => Number.isNaN(x))) {
    return new Date().toISOString();
  }
  const now = new Date();
  const merged = new Date(parts[0], parts[1] - 1, parts[2], now.getHours(), now.getMinutes(), now.getSeconds());
  return merged.toISOString();
}

function thisMonthKey() {
  return new Date().toISOString().slice(0, 7);
}

function monthlyInsightPayload() {
  const monthKey = thisMonthKey();
  const monthItems = state.items.filter((x) => x.createdAt.startsWith(monthKey));
  const totalExpense = monthItems.filter((x) => x.amount > 0).reduce((sum, x) => sum + x.amount, 0);
  const categoryMap = {};
  monthItems.forEach((item) => {
    categoryMap[item.category] = (categoryMap[item.category] || 0) + Math.max(item.amount, 0);
  });
  const top = Object.entries(categoryMap).sort((a, b) => b[1] - a[1])[0];
  const topCategory = top?.[0] || "暂无";
  const topAmount = top?.[1] || 0;
  return {
    monthKey,
    summary: `${monthKey.replace("-", "年")}月总支出 ${formatCNY(totalExpense)}，主要支出集中在${topCategory}。`,
    structure: `本月记录 ${monthItems.length} 笔，其中${topCategory}占比最高，约 ${totalExpense ? Math.round((topAmount / totalExpense) * 100) : 0}% 。`,
    advice:
      totalExpense > 1000
        ? "建议下月给高频分类设置预算上限，并每周复盘一次，波动会明显收敛。"
        : "本月支出节奏整体平稳，继续保持按笔记录，下月更容易看见结构变化。",
    createdAt: new Date().toISOString(),
  };
}

function rangeInsightPayload(days, label) {
  const end = new Date();
  const start = new Date();
  start.setDate(end.getDate() - (days - 1));
  start.setHours(0, 0, 0, 0);
  const items = state.items.filter((x) => new Date(x.createdAt) >= start && x.amount > 0);
  const totalExpense = items.reduce((sum, x) => sum + x.amount, 0);
  const categoryMap = {};
  items.forEach((item) => {
    categoryMap[item.category] = (categoryMap[item.category] || 0) + item.amount;
  });
  const top = Object.entries(categoryMap).sort((a, b) => b[1] - a[1])[0];
  const topCategory = top?.[0] || "暂无";
  const topAmount = top?.[1] || 0;
  return {
    summary: `${label}总支出 ${formatCNY(totalExpense)}，主要集中在${topCategory}。`,
    structure: `${label}共记录 ${items.length} 笔，${topCategory}占比约 ${totalExpense ? Math.round((topAmount / totalExpense) * 100) : 0}% 。`,
    advice:
      totalExpense > 3000
        ? "建议对高频支出分类设置分段预算，并在每周末回看预算达成率。"
        : "整体支出节奏可控，继续保持按笔记录，长期会更容易优化消费结构。",
  };
}

function openMonthlyTrialModal(title, body) {
  refs.monthlyTrialModalTitle.textContent = title;
  refs.monthlyTrialModalBody.textContent = body;
  refs.monthlyTrialModal.classList.remove("hidden");
}

function openAccountOverlay() {
  accountOverlayView = state.settings.isLoggedIn ? "center" : "login";
  refs.accountOverlay.classList.remove("hidden");
  renderAccountOverlay();
}

function closeAccountOverlay() {
  refs.accountOverlay.classList.add("hidden");
}

function renderAccountOverlay() {
  const isLoggedIn = Boolean(state.settings.isLoggedIn);
  const accountName = state.settings.displayName || "轻账用户";
  if (!isLoggedIn) {
    accountOverlayView = "login";
  } else if (accountOverlayView === "login") {
    accountOverlayView = "center";
  }
  refs.accountLoginView.classList.toggle("hidden", accountOverlayView !== "login");
  refs.accountCenterView.classList.toggle("hidden", accountOverlayView !== "center");
  refs.accountMemberView.classList.toggle("hidden", accountOverlayView !== "member");
  refs.accountCenterName.textContent = `你好呀，${accountName}`;
  refs.accountCenterAvatar.textContent = "🐱";
  refs.accountCenterState.textContent = `当前状态：${state.settings.isMember ? "会员版" : "免费版"}`;
  refs.accountUpgradeEntryBtn.classList.toggle("hidden", state.settings.isMember);
  const showPetNicknameEditor = Boolean(state.settings.isMember);
  refs.accountPetNicknameInput.closest(".account-petname-field")?.classList.toggle("hidden", !showPetNicknameEditor);
  refs.accountPetNicknameSaveBtn.classList.toggle("hidden", !showPetNicknameEditor);
  refs.accountPetNicknameTip.classList.toggle("hidden", !showPetNicknameEditor);
  refs.accountPetNicknameInput.value = state.settings.userPetNickname || "";
  refs.accountPetNicknameInput.disabled = !showPetNicknameEditor;
  refs.accountPetNicknameSaveBtn.disabled = !showPetNicknameEditor;
  refs.accountPetNicknameTip.textContent = showPetNicknameEditor
    ? "可输入 2-6 个字，保存后将用于宠物包与宠物对话文案。"
    : "升级会员后可自定义宠物昵称，自动联动宠物包备注与互动文案。";
}

function closeMonthlyTrialModal() {
  refs.monthlyTrialModal.classList.add("hidden");
}

async function generateMonthlyInsight() {
  const TRIAL_TOTAL = 5;
  if (state.isGeneratingMonthlyInsight) return;
  if (state.monthlyTrialUsed >= TRIAL_TOTAL) {
    openMonthlyTrialModal(
      "免费次数已用完",
      "您的免费月度复盘次数已用完，升级会员即可解锁无限次月度/季度/年度 AI 复盘，还有更多专属权益等你体验。"
    );
    return;
  }

  const firstTime = state.monthlyTrialUsed === 0;
  state.isGeneratingMonthlyInsight = true;
  renderInsight();
  await new Promise((resolve) => setTimeout(resolve, 800));
  const report = monthlyInsightPayload();
  state.monthlyInsights = [report, ...state.monthlyInsights.filter((x) => x.monthKey !== report.monthKey)];
  state.monthlyTrialUsed += 1;
  state.isGeneratingMonthlyInsight = false;
  persist();
  renderInsight();

  const left = TRIAL_TOTAL - state.monthlyTrialUsed;
  if (firstTime) {
    openMonthlyTrialModal(
      "🎁 新用户福利",
      `您已获得 5 次免费月度 AI 复盘机会，本次消耗 1 次，剩余 ${left} 次。`
    );
    return;
  }
  openMonthlyTrialModal("月度复盘已生成", `本次消耗 1 次免费次数，剩余 ${left} 次。`);
  showPetBubble(buildAiReviewPetMessage());
}

function generatePremiumInsight(label, days) {
  if (!state.settings.isMember) {
    openMonthlyTrialModal("会员专属权益", "季度 / 年度复盘为会员专属权益，升级会员即可解锁。");
    return;
  }
  const report = rangeInsightPayload(days, label);
  refs.monthlyInsightContent.classList.remove("hidden");
  refs.monthlyInsightSummary.textContent = report.summary;
  refs.monthlyInsightStructure.textContent = report.structure;
  refs.monthlyInsightAdvice.textContent = report.advice;
  showToast(`${label}已生成`);
  showPetBubble(buildAiReviewPetMessage());
}

async function generateTodayInsight() {
  if (state.isGeneratingInsight) return;
  state.isGeneratingInsight = true;
  renderInsight();

  await new Promise((resolve) => setTimeout(resolve, 750));

  const dayKey = new Date().toISOString().slice(0, 10);
  state.insights = state.insights.filter((x) => x.dayKey !== dayKey);
  const todayItems = state.items.filter((x) => x.createdAt.slice(0, 10) === dayKey);
  const total = todayItems.reduce((sum, x) => sum + x.amount, 0);
  const topCategory = topCategoryFor(todayItems) || "暂无";

  const insight = {
    id: crypto.randomUUID(),
    dayKey,
    summary: `${state.settings.displayName}，今天总支出 ${formatCNY(total)}，主要花在${topCategory}。`,
    action: total > 100 ? "明天把一笔冲动小额消费换成计划内消费，会更轻松。" : "今天节奏很稳，继续保持每笔记录就很好。",
    encourage: total > 0 ? "你今天控制得很好，继续保持就很棒。" : "今天还没消费也没关系，保持记录习惯就很好。",
    createdAt: new Date().toISOString(),
  };
  state.insights.unshift(insight);
  state.isGeneratingInsight = false;
  persist();
  render();
  showPetBubble(buildAiReviewPetMessage());
}

function topCategoryFor(items) {
  const map = {};
  items.forEach((item) => {
    map[item.category] = (map[item.category] || 0) + item.amount;
  });
  return Object.entries(map).sort((a, b) => b[1] - a[1])[0]?.[0];
}

function renderHome() {
  const todayKey = new Date().toISOString().slice(0, 10);
  const todayItems = state.items.filter((x) => x.createdAt.slice(0, 10) === todayKey);
  const weekItems = state.items.filter((x) => sameWeek(x.createdAt));
  const todayTotal = todayItems.reduce((sum, x) => sum + x.amount, 0);
  const weekTotal = weekItems.reduce((sum, x) => sum + x.amount, 0);

  refs.todayTotal.textContent = formatCNY(todayTotal);
  refs.weekTotal.textContent = `本周累计 ${formatCNY(weekTotal)}`;

  refs.homeTodayList.innerHTML = "";
  const recent = [...todayItems]
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
    .slice(0, 3);
  refs.homeTodayEmptyArt.classList.toggle("hidden", recent.length > 0);
  recent.forEach((item) => {
    const li = document.createElement("li");
    li.className = "home-record-item";
    li.tabIndex = 0;
    li.innerHTML = `
      <div class="item-title-row">
        <span>${item.title}</span>
        <span>${formatCNY(item.amount)}</span>
      </div>
      <p class="muted">${item.category} · ${new Date(item.createdAt).toLocaleString()}</p>
    `;
    const openEditor = () => openRecordEditor(item.id);
    li.addEventListener("click", openEditor);
    li.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        openEditor();
      }
    });
    refs.homeTodayList.appendChild(li);
  });

  const todayInsight = state.insights.find((x) => x.dayKey === todayKey);
  refs.homeInsightSummary.textContent = todayInsight ? `${todayInsight.summary} ${todayInsight.action}` : "记几笔账，明天来这里看 AI 给你的专属小结。";
  refs.homeInsightSummary.classList.toggle("muted", !todayInsight);
  refs.homeInsightSummary.classList.toggle("compact", Boolean(todayInsight));
  refs.homeInsightHint.textContent = "";
  refs.dailyNudge.textContent = "花 10 秒，轻松记一笔";
}

function resetRecordEditorState() {
  editingRecordId = null;
  refs.recordFormTitle.textContent = "记账";
  refs.deleteRecordBtn.classList.add("hidden");
}

function openRecordEditor(recordId) {
  const item = state.items.find((x) => x.id === recordId);
  if (!item) return;
  editingRecordId = recordId;
  state.recordMode = "manual";
  refs.recordFormTitle.textContent = "编辑账单";
  refs.deleteRecordBtn.classList.remove("hidden");
  refs.titleInput.value = item.title || "";
  amountStream = parseAmountTextToStream(String(item.amount.toFixed(2)));
  updateAmountInputFromStream();
  selectedCategory = item.category || "其他";
  categoryLockedByUser = true;
  refs.recordDateInput.value = item.createdAt.slice(0, 10);
  switchTab("record");
  renderRecord();
}

function renderRecord() {
  const amountReady = isAmountReady();
  const isEditing = Boolean(editingRecordId);
  refs.recordModeSegment.classList.toggle("hidden", Boolean(editingRecordId));
  refs.modeButtons.forEach((btn) => btn.classList.toggle("active", btn.dataset.mode === state.recordMode));
  refs.manualForm.classList.toggle("hidden", state.recordMode !== "manual");
  refs.ocrForm.classList.toggle("hidden", state.recordMode !== "ocr");
  refs.deleteRecordBtn.classList.toggle("hidden", editingRecordId == null || state.recordMode !== "manual");
  refs.recordFormTitle.textContent = editingRecordId ? "编辑账单" : "记账";
  if (state.recordMode !== "manual") {
    renderOCRDraftArea();
    return;
  }

  const wasDisabled = refs.saveRecordBtn.disabled;
  refs.categoryField.classList.toggle("hidden", !amountReady && !isEditing);
  refs.noteField.classList.toggle("hidden", !amountReady && !isEditing);
  refs.amountAssist.classList.toggle("hidden", amountReady || isEditing);
  refs.networkHint.classList.toggle("hidden", !amountReady || !state.settings.remoteAIEnabled || isEditing);
  refs.dateHint.classList.toggle("hidden", !amountReady && !isEditing);
  refs.localPrivacyHint.classList.toggle("hidden", !amountReady && !isEditing);
  refs.editDateBtn.classList.toggle("hidden", !amountReady && !isEditing);
  refs.saveRecordBtn.disabled = !amountReady;
  if (wasDisabled && amountReady) {
    refs.saveRecordBtn.classList.remove("save-ready");
    requestAnimationFrame(() => {
      refs.saveRecordBtn.classList.add("save-ready");
      setTimeout(() => refs.saveRecordBtn.classList.remove("save-ready"), 220);
    });
  }

  if (!amountReady && !isEditing) {
    refs.noteSuggestions.classList.add("hidden");
  }
  updateCategoryUI();
  renderMemberScenePacks();
}

function renderStats() {
  const period = refs.billDateFilter.value;
  const category = refs.billCategoryFilter.value;

  const categoryOptions = ["", ...new Set(state.items.map((x) => x.category))];
  const currentSelect = refs.billCategoryFilter.value;
  refs.billCategoryFilter.innerHTML = categoryOptions
    .map((c) => `<option value="${c}">${c || "全部分类"}</option>`)
    .join("");
  refs.billCategoryFilter.value = currentSelect && categoryOptions.includes(currentSelect) ? currentSelect : "";

  let filtered = state.items.filter((item) => {
    if (period === "week" && !sameWeek(item.createdAt)) return false;
    if (period === "month" && !sameMonth(item.createdAt)) return false;
    if (period === "year" && !sameYear(item.createdAt)) return false;
    if (category && item.category !== category) return false;
    return item.amount > 0;
  });

  filtered = filtered.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

  const expenseTotal = filtered.filter((x) => x.amount > 0).reduce((sum, x) => sum + x.amount, 0);
  refs.billExpenseTotal.textContent = formatCNY(expenseTotal);
  renderBillTrendChart();

  refs.billRecordsList.innerHTML = "";
  refs.billRecordsEmpty.style.display = filtered.length ? "none" : "block";
  filtered.forEach((item) => {
    const li = document.createElement("li");
    li.className = "home-record-item";
    li.tabIndex = 0;
    li.innerHTML = `
      <div class="item-title-row">
        <span>${item.title}</span>
        <span>${formatCNY(item.amount)}</span>
      </div>
      <p class="muted">${item.category} · ${new Date(item.createdAt).toLocaleString()}</p>
    `;
    const openEditor = () => openRecordEditor(item.id);
    li.addEventListener("click", openEditor);
    li.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        openEditor();
      }
    });
    refs.billRecordsList.appendChild(li);
  });
}

function renderBillTrendChart() {
  const days = 30;
  const totalsByDay = [];
  const today = new Date();
  for (let i = days - 1; i >= 0; i -= 1) {
    const d = new Date(today);
    d.setDate(today.getDate() - i);
    const key = d.toISOString().slice(0, 10);
    const total = state.items
      .filter((item) => item.amount > 0 && item.createdAt.slice(0, 10) === key)
      .reduce((sum, item) => sum + item.amount, 0);
    totalsByDay.push(total);
  }
  const max = Math.max(...totalsByDay, 1);
  const width = 300;
  const height = 90;
  const padX = 8;
  const padY = 8;
  const innerW = width - padX * 2;
  const innerH = height - padY * 2;
  const points = totalsByDay
    .map((value, idx) => {
      const x = padX + (idx / (days - 1)) * innerW;
      const y = padY + innerH - (value / max) * innerH;
      return `${x.toFixed(2)},${y.toFixed(2)}`;
    })
    .join(" ");
  refs.billTrendLine.setAttribute("points", points);
  const peakValue = Math.max(...totalsByDay);
  const peakIndex = totalsByDay.indexOf(peakValue);
  const peakX = padX + (peakIndex / (days - 1)) * innerW;
  const peakY = padY + innerH - (peakValue / max) * innerH;
  refs.billTrendPeakDot.setAttribute("cx", peakX.toFixed(2));
  refs.billTrendPeakDot.setAttribute("cy", peakY.toFixed(2));
  refs.billTrendPeakLabel.setAttribute("x", Math.min(width - 76, peakX + 6).toFixed(2));
  refs.billTrendPeakLabel.setAttribute("y", Math.max(14, peakY - 6).toFixed(2));
  refs.billTrendPeakLabel.textContent = formatCNY(peakValue);
  refs.billTrendMaxLabel.textContent = formatCNY(max);

  const recent7 = totalsByDay.slice(-7).reduce((sum, x) => sum + x, 0);
  const prev7 = totalsByDay.slice(-14, -7).reduce((sum, x) => sum + x, 0);
  if (recent7 > prev7 * 1.15) {
    refs.billTrendInsight.textContent = "最近一周支出有上升趋势，建议关注高频消费分类。";
  } else if (recent7 < prev7 * 0.85) {
    refs.billTrendInsight.textContent = "最近一周支出明显回落，当前消费节奏更稳了。";
  } else {
    refs.billTrendInsight.textContent = "本月支出整体平稳，保持记录就很棒。";
  }
}

function renderInsight() {
  const TRIAL_TOTAL = 5;
  const todayKey = new Date().toISOString().slice(0, 10);
  const todayInsight = state.insights.find((x) => x.dayKey === todayKey);
  refs.insightSummary.textContent = todayInsight ? todayInsight.summary : "还没有今日复盘。";
  refs.insightAction.textContent = todayInsight ? todayInsight.action : "";
  refs.insightEncourage.textContent = todayInsight ? todayInsight.encourage : "";

  refs.insightHistory.innerHTML = "";
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 6);
  sevenDaysAgo.setHours(0, 0, 0, 0);

  const recentInsights = state.insights
    .filter((insight) => new Date(insight.createdAt) >= sevenDaysAgo)
    .slice(0, 7);
  refs.insightHistoryEmpty.style.display = recentInsights.length ? "none" : "block";

  recentInsights.forEach((insight) => {
    const li = document.createElement("li");
    li.innerHTML = `
      <div class="item-title-row"><span>${insight.dayKey}</span><span>每日建议</span></div>
      <p>${insight.summary}</p>
      <p class="muted">${insight.action}</p>
    `;
    refs.insightHistory.appendChild(li);
  });

  refs.generateInsightBtn.disabled = state.isGeneratingInsight;
  refs.generateInsightBtn.textContent = state.isGeneratingInsight ? INSIGHT_BTN_LOADING_TEXT : INSIGHT_BTN_IDLE_TEXT;
  refs.generateInsightBtn.classList.toggle("generating", state.isGeneratingInsight);

  const monthKey = thisMonthKey();
  const monthlyReport = state.monthlyInsights.find((x) => x.monthKey === monthKey) || state.monthlyInsights[0];
  const left = Math.max(0, TRIAL_TOTAL - state.monthlyTrialUsed);
  const isMonthlyLocked = !state.settings.isMember && left === 0;
  refs.monthlyTrialText.textContent = `剩余试用次数：${left}/${TRIAL_TOTAL}`;
  refs.generateMonthlyInsightBtn.disabled = state.isGeneratingMonthlyInsight;
  refs.generateMonthlyInsightBtn.classList.toggle("primary-btn", !isMonthlyLocked);
  refs.generateMonthlyInsightBtn.classList.toggle("locked-report-btn", isMonthlyLocked);
  if (state.isGeneratingMonthlyInsight) {
    refs.generateMonthlyInsightBtn.textContent = "正在生成月度复盘...";
  } else if (isMonthlyLocked) {
    refs.generateMonthlyInsightBtn.innerHTML = '<span class="lock-icon">🔒︎</span>生成月度复盘';
  } else {
    refs.generateMonthlyInsightBtn.textContent = "生成月度复盘";
  }
  refs.monthlyInsightContent.classList.toggle("hidden", !monthlyReport);
  if (monthlyReport) {
    refs.monthlyInsightSummary.textContent = monthlyReport.summary;
    refs.monthlyInsightStructure.textContent = monthlyReport.structure;
    refs.monthlyInsightAdvice.textContent = monthlyReport.advice;
  }
  const memberUnlocked = state.settings.isMember;
  refs.generateQuarterlyInsightBtn.classList.toggle("member-unlocked", memberUnlocked);
  refs.generateYearlyInsightBtn.classList.toggle("member-unlocked", memberUnlocked);
  refs.generateQuarterlyInsightBtn.innerHTML = memberUnlocked
    ? "生成季度复盘"
    : '<span class="lock-icon">🔒︎</span>生成季度复盘';
  refs.generateYearlyInsightBtn.innerHTML = memberUnlocked
    ? "生成年度复盘"
    : '<span class="lock-icon">🔒︎</span>生成年度复盘';
}

function renderSettings() {
  const accountName = state.settings.displayName || "轻账用户";
  const isLoggedIn = Boolean(state.settings.isLoggedIn);
  refs.accountAvatar.textContent = isLoggedIn ? "🐱" : "👤";
  refs.accountEntryText.textContent = isLoggedIn
    ? `${accountName} > 管理账号与会员。`
    : "点击登录，解锁云备份与会员权益 >";
  refs.displayNameInput.value = state.settings.displayName;
  refs.syncSwitch.checked = state.settings.syncEnabled;
  refs.remoteAISwitch.checked = state.settings.remoteAIEnabled;
  refs.petCompanionSwitch.checked = state.settings.petCompanionEnabled;
  refs.weatherCompanionSwitch.checked = state.settings.weatherCompanionEnabled;
  const showWeatherSetting = state.settings.petCompanionEnabled;
  refs.weatherCompanionRow.classList.toggle("hidden", !showWeatherSetting);
  refs.weatherCompanionHelper.classList.toggle("hidden", !showWeatherSetting);
}

function render() {
  applyTheme();
  renderHome();
  renderRecord();
  renderStats();
  renderInsight();
  renderSettings();
}

function openGuide() {
  guideStep = 1;
  refs.guideOverlay.classList.remove("hidden");
  renderGuideStep();
}

function closeGuide(done = false) {
  refs.guideOverlay.classList.add("hidden");
  if (done) {
    localStorage.setItem(GUIDE_KEY, "1");
  }
}

function renderGuideStep() {
  const card = guideCards[guideStep - 1];
  refs.guideStepText.textContent = `第 ${guideStep} 张 / ${guideCards.length}`;
  refs.guideTitle.textContent = card.title;
  refs.guideDesc.textContent = card.desc;
  refs.guideNextBtn.textContent = guideStep >= guideCards.length ? "完成" : "下一步";
}

function init() {
  refs.todayText.textContent = new Date().toLocaleDateString("zh-CN", {
    month: "long",
    day: "numeric",
    weekday: "short",
  });
  refs.recordDateInput.value = new Date().toISOString().slice(0, 10);
  refs.editDateBtn.addEventListener("click", () => {
    if (typeof refs.recordDateInput.showPicker === "function") {
      refs.recordDateInput.showPicker();
    } else {
      refs.recordDateInput.click();
    }
  });
  refs.recordDateInput.addEventListener("change", () => {
    if (refs.recordDateInput.value) {
      showToast(`已切换为补记日期：${refs.recordDateInput.value}`);
    }
  });
  selectedCategory = topCategoryFromHistory();
  amountStream = parseAmountTextToStream(refs.amountInput.value);
  updateAmountInputFromStream();
  updateCategoryUI();
  refs.amountInput.addEventListener("keydown", handleAmountInputKeydown);
  refs.amountInput.addEventListener("paste", (event) => {
    event.preventDefault();
    const pastedText = event.clipboardData?.getData("text") || "";
    amountStream = parseAmountTextToStream(pastedText);
    syncAmountUIAfterInput();
  });
  refs.amountInput.addEventListener("input", () => {
    amountStream = parseAmountTextToStream(refs.amountInput.value);
    updateAmountInputFromStream();
    if (!editingRecordId && isAmountReady()) {
      scheduleCategoryRecommendation();
    }
    renderRecord();
  });
  refs.amountInput.addEventListener("focus", () => {
    document.querySelector(".app-shell")?.classList.add("keyboard-active");
    isAmountInputFocused = true;
    renderAmountDisplay();
    setTimeout(() => {
      refs.amountInput.scrollIntoView({ behavior: "smooth", block: "center" });
    }, 120);
  });
  refs.amountInput.addEventListener("blur", () => {
    document.querySelector(".app-shell")?.classList.remove("keyboard-active");
    isAmountInputFocused = false;
    renderAmountDisplay();
    renderRecord();
  });
  refs.titleInput.addEventListener("input", () => {
    renderNoteSuggestions();
    if (!editingRecordId) {
      scheduleCategoryRecommendation();
    }
  });
  refs.titleInput.addEventListener("blur", () => {
    setTimeout(() => {
      refs.noteSuggestions.classList.add("hidden");
    }, 120);
  });
  refs.tabs.forEach((btn) => btn.addEventListener("click", () => switchTab(btn.dataset.tab)));
  refs.jumpButtons.forEach((btn) => btn.addEventListener("click", () => switchTab(btn.dataset.jump)));
  refs.quickManualBtn?.addEventListener("click", () => switchTab("record"));

  refs.modeButtons.forEach((btn) =>
    btn.addEventListener("click", () => {
      if (btn.dataset.mode !== "manual") {
        resetRecordEditorState();
      }
      state.recordMode = btn.dataset.mode;
      persist();
      renderRecord();
    })
  );

  [refs.billDateFilter, refs.billCategoryFilter].forEach((el) => {
    el.addEventListener("change", renderStats);
  });

  refs.saveRecordBtn.addEventListener("click", async () => {
    const wasEditing = Boolean(editingRecordId);
    const draftRecordContext = {
      title: refs.titleInput.value.trim(),
      category: selectedCategory || "其他",
      amount: getAmountValue(),
      createdAt: refs.recordDateInput.value,
    };
    let ok = false;
    if (editingRecordId) {
      const current = state.items.find((x) => x.id === editingRecordId);
      const amount = getAmountValue();
      if (!current || !amount || Number.isNaN(amount) || amount <= 0) {
        showToast("请先填写有效金额。");
      } else {
        const finalCategory = selectedCategory || "其他";
        current.title = refs.titleInput.value.trim() || `${finalCategory}消费`;
        current.amount = amount;
        current.category = finalCategory;
        current.createdAt = mergeDateWithCurrentTime(refs.recordDateInput.value);
        persist();
        render();
        ok = true;
      }
    } else {
      ok = addRecord({
        title: refs.titleInput.value.trim(),
        amount: getAmountValue(),
        category: selectedCategory || "其他",
        source: "manual",
        occurredAt: refs.recordDateInput.value,
      });
    }
    if (ok) {
      refs.titleInput.value = "";
      amountStream = { intPart: "", decPart: "", hasDot: false };
      updateAmountInputFromStream();
      selectedCategory = topCategoryFromHistory();
      categoryLockedByUser = false;
      resetRecordEditorState();
      updateCategoryUI();
      refs.noteSuggestions.classList.add("hidden");
      refs.noteSuggestions.innerHTML = "";
      refs.recordDateInput.value = new Date().toISOString().slice(0, 10);
      showToast(wasEditing ? "账单已更新" : "手动记录已保存");
      if (!wasEditing) {
        const streakDays = consecutiveRecordDays();
        const recordText =
          streakDays >= 2
            ? pickRandom(petCopy.streak).replace("{days}", String(streakDays))
            : await buildContextualPetMessage(draftRecordContext);
        switchTab("home");
        setTimeout(() => showPetBubble(recordText), 120);
        return;
      }
      switchTab("home");
    }
  });
  refs.deleteRecordBtn.addEventListener("click", () => {
    if (!editingRecordId) return;
    const idx = state.items.findIndex((x) => x.id === editingRecordId);
    if (idx < 0) return;
    state.items.splice(idx, 1);
    persist();
    render();
    refs.titleInput.value = "";
    amountStream = { intPart: "", decPart: "", hasDot: false };
    updateAmountInputFromStream();
    selectedCategory = topCategoryFromHistory();
    categoryLockedByUser = false;
    resetRecordEditorState();
    refs.recordDateInput.value = new Date().toISOString().slice(0, 10);
    showToast("账单已删除");
    switchTab("home");
  });

  refs.ocrPickImageBtn.addEventListener("click", () => {
    refs.ocrImageInput.click();
  });
  refs.ocrImageInput.addEventListener("change", async () => {
    const file = refs.ocrImageInput.files?.[0];
    if (!file) return;
    const result = await runMockOCR(file);
    openOCRConfirm(result);
    refs.ocrImageInput.value = "";
  });
  refs.ocrCancelBtn.addEventListener("click", () => {
    closeOCRConfirm();
  });
  refs.ocrClearResolvedBtn.addEventListener("click", () => {
    const draftItems = draftItemsByRecentBatches();
    if (!draftItems.length) {
      showToast("还没有导入账单哦");
      return;
    }
    const resolvedCount = draftItems.filter((x) => x.draftMeta?.status === "resolved").length;
    if (resolvedCount === 0) {
      showToast("还没有已整理的账单");
      return;
    }
    clearResolvedDraftMarks();
    showToast(`已完成整理 ${resolvedCount} 条账单`);
  });
  refs.ocrCategoryOverlay.addEventListener("click", (event) => {
    if (event.target === refs.ocrCategoryOverlay) {
      closeDraftCategoryPicker();
    }
  });
  refs.ocrSelectAllBtn.addEventListener("click", () => {
    const selectedCount = ocrDraftRecords.filter((x) => x.selected !== false).length;
    const nextChecked = selectedCount !== ocrDraftRecords.length;
    ocrDraftRecords = ocrDraftRecords.map((x) => ({ ...x, selected: nextChecked }));
    renderOCRConfirmList(ocrDraftRecords);
    updateOCRSelectionState();
  });
  refs.ocrInvertBtn.addEventListener("click", () => {
    ocrDraftRecords = ocrDraftRecords.map((x) => ({ ...x, selected: x.selected === false }));
    renderOCRConfirmList(ocrDraftRecords);
    updateOCRSelectionState();
  });
  refs.ocrBatchCategorySelect.addEventListener("change", () => {
    const category = refs.ocrBatchCategorySelect.value;
    if (!category) return;
    let changed = 0;
    const changedIndexes = [];
    ocrDraftRecords = ocrDraftRecords.map((x, index) => {
      if (x.selected === false) return x;
      if (x.category === category) return x;
      changed += 1;
      changedIndexes.push(index);
      return { ...x, category };
    });
    renderOCRConfirmList(ocrDraftRecords);
    updateOCRSelectionState();
    changedIndexes.forEach((idx) => animateOCRRowChanged(idx));
    if (changed > 0) {
      showToast(`已批量更新 ${changed} 条分类`);
    }
    refs.ocrBatchCategorySelect.value = "";
  });
  refs.ocrConfirmBtn.addEventListener("click", () => {
    const importedCount = importOCRRecords(ocrDraftRecords);
    closeOCRConfirm();
    if (importedCount > 0) {
      state.recordMode = "ocr";
      persist();
      switchTab("record");
      renderRecord();
      showToast(`已成功导入 ${importedCount} 条账单`);
    } else {
      showToast("没有可导入的账单");
    }
  });

  refs.generateInsightBtn.addEventListener("click", generateTodayInsight);
  refs.generateMonthlyInsightBtn.addEventListener("click", generateMonthlyInsight);
  refs.petBtn.addEventListener("pointerdown", () => {
    petLongPressTriggered = false;
    clearTimeout(petPressTimer);
    petPressTimer = setTimeout(() => {
      petLongPressTriggered = true;
      sessionStorage.setItem(PET_HIDE_SESSION_KEY, "1");
      state.settings.petCompanionEnabled = false;
      persist();
      refs.petCompanionSwitch.checked = false;
      refs.petWidget.classList.add("pet-hiding");
      setTimeout(() => {
        updatePetVisibility();
      }, 180);
      showToast("宠物陪伴已关闭，可在设置中重新开启");
    }, 650);
  });
  ["pointerup", "pointercancel", "pointerleave"].forEach((eventName) => {
    refs.petBtn.addEventListener(eventName, () => {
      clearTimeout(petPressTimer);
    });
  });
  refs.petBtn.addEventListener("click", () => {
    if (petLongPressTriggered) return;
    const pool = [...petCopy.companion, ...petCopy.lightScene];
    if (!state.settings.weatherCompanionEnabled && Math.random() < 0.22) {
      pool.push(...petCopy.weatherHint);
    }
    showPetBubble(pickRandom(pool));
  });
  refs.petBubble.addEventListener("click", () => {
    if (!refs.petBubble.textContent?.includes("前往设置开启")) return;
    switchTab("settings");
  });
  refs.generateQuarterlyInsightBtn.addEventListener("click", () => generatePremiumInsight("季度复盘", 90));
  refs.generateYearlyInsightBtn.addEventListener("click", () => generatePremiumInsight("年度复盘", 365));
  refs.monthlyTrialModalOkBtn.addEventListener("click", closeMonthlyTrialModal);
  refs.monthlyTrialUpgradeBtn.addEventListener("click", () => {
    closeMonthlyTrialModal();
    switchTab("settings");
    showToast("可在设置页开启会员权益（演示入口）");
  });
  refs.monthlyTrialModal.addEventListener("click", (event) => {
    if (event.target === refs.monthlyTrialModal) {
      closeMonthlyTrialModal();
    }
  });

  refs.displayNameInput.addEventListener("input", (e) => {
    state.settings.displayName = e.target.value.trim() || "轻账用户";
    persist();
    renderHome();
    renderSettings();
    renderAccountOverlay();
  });
  refs.accountEntryBtn.addEventListener("click", () => {
    openAccountOverlay();
  });
  refs.accountCloseBtn.addEventListener("click", closeAccountOverlay);
  refs.accountSkipBtn.addEventListener("click", closeAccountOverlay);
  refs.accountOverlay.addEventListener("click", (event) => {
    if (event.target === refs.accountOverlay) {
      closeAccountOverlay();
    }
  });
  const mockLogin = () => {
    state.settings.isLoggedIn = true;
    persist();
    accountOverlayView = "center";
    renderSettings();
    renderAccountOverlay();
    showToast("登录成功，已解锁账号同步入口");
  };
  refs.accountPhoneLoginBtn.addEventListener("click", mockLogin);
  refs.accountWechatLoginBtn.addEventListener("click", mockLogin);
  refs.memberScenePackEntryBtn.addEventListener("click", () => {
    openAccountOverlay();
    accountOverlayView = "member";
    renderAccountOverlay();
  });
  refs.accountUpgradeEntryBtn.addEventListener("click", () => {
    accountOverlayView = "member";
    renderAccountOverlay();
  });
  refs.accountMemberBackBtn.addEventListener("click", () => {
    accountOverlayView = "center";
    renderAccountOverlay();
  });
  const tryUpgrade = (planName) => {
    if (!window.confirm("升级后，小宠物就能陪你解锁更多玩法啦，确定要升级吗？")) return;
    state.settings.isLoggedIn = true;
    state.settings.isMember = true;
    persist();
    accountOverlayView = "center";
    renderSettings();
    renderInsight();
    renderAccountOverlay();
    showToast(`${planName}开通成功，已解锁会员权益`);
  };
  refs.buyMonthlyBtn.addEventListener("click", () => tryUpgrade("月度会员"));
  refs.buyYearlyBtn.addEventListener("click", () => tryUpgrade("年度会员"));
  refs.buyLifetimeBtn.addEventListener("click", () => tryUpgrade("永久会员"));
  refs.accountBindPhoneBtn.addEventListener("click", () => {
    showToast("绑定手机号功能开发中");
  });
  refs.accountPetNicknameSaveBtn.addEventListener("click", () => {
    if (!state.settings.isMember) {
      showToast("升级会员后可自定义宠物昵称");
      return;
    }
    const nextName = (refs.accountPetNicknameInput.value || "").trim();
    if (!/^[\u4e00-\u9fa5A-Za-z0-9]{2,6}$/.test(nextName)) {
      showToast("昵称需 2-6 个字，且不含特殊符号");
      return;
    }
    state.settings.userPetNickname = nextName;
    persist();
    renderAccountOverlay();
    renderMemberScenePacks();
    showToast(`已为小宠物命名：${nextName}`);
  });
  refs.accountLogoutBtn.addEventListener("click", () => {
    if (!window.confirm("确定要退出吗？本地数据不会丢失")) return;
    state.settings.isLoggedIn = false;
    state.settings.isMember = false;
    persist();
    renderSettings();
    renderAccountOverlay();
    closeAccountOverlay();
    showToast("已退出登录");
  });
  refs.syncSwitch.addEventListener("change", (e) => {
    state.settings.syncEnabled = e.target.checked;
    persist();
  });
  refs.remoteAISwitch.addEventListener("change", (e) => {
    state.settings.remoteAIEnabled = e.target.checked;
    persist();
    if (!categoryLockedByUser) {
      scheduleCategoryRecommendation();
    }
  });
  refs.petCompanionSwitch.addEventListener("change", (e) => {
    state.settings.petCompanionEnabled = e.target.checked;
    if (e.target.checked) {
      // 用户手动重新开启时，取消本次会话的长按隐藏状态
      sessionStorage.removeItem(PET_HIDE_SESSION_KEY);
      refs.petWidget.classList.remove("pet-hiding");
    } else {
      refs.petBubble.classList.add("hidden");
      state.settings.weatherCompanionEnabled = false;
      refs.weatherCompanionSwitch.checked = false;
    }
    persist();
    updatePetVisibility();
    renderSettings();
  });
  refs.weatherCompanionSwitch.addEventListener("change", async (e) => {
    if (!state.settings.petCompanionEnabled) {
      e.target.checked = false;
      state.settings.weatherCompanionEnabled = false;
      persist();
      return;
    }
    if (!e.target.checked) {
      state.settings.weatherCompanionEnabled = false;
      persist();
      showToast("已关闭天气场景互动");
      return;
    }
    if (isRequestingWeatherPermission) {
      e.target.checked = false;
      return;
    }
    // 先回到关闭态，避免用户关闭系统弹窗后开关卡在开启状态
    e.target.checked = false;
    state.settings.weatherCompanionEnabled = false;
    persist();
    isRequestingWeatherPermission = true;
    const granted = await requestWeatherPermissionFlow();
    isRequestingWeatherPermission = false;
    if (!granted) {
      state.settings.weatherCompanionEnabled = false;
      persist();
      showToast("未获取定位权限，仍使用通用温柔文案");
      return;
    }
    e.target.checked = true;
    state.settings.weatherCompanionEnabled = true;
    persist();
    showToast("天气场景互动已开启");
  });
  refs.resetGuideBtn.addEventListener("click", () => {
    localStorage.removeItem(GUIDE_KEY);
    openGuide();
  });
  refs.appearanceButtons.forEach((btn) =>
    btn.addEventListener("click", () => {
      state.settings.appearance = btn.dataset.appearance;
      persist();
      applyTheme();
    })
  );
  systemThemeQuery.addEventListener("change", () => state.settings.appearance === "system" && applyTheme());

  refs.guideSkipBtn.addEventListener("click", () => closeGuide(true));
  refs.guideNextBtn.addEventListener("click", () => {
    if (guideStep < guideCards.length) {
      guideStep += 1;
      renderGuideStep();
      return;
    }
    closeGuide(true);
    switchTab("home");
  });

  switchTab("home");
  render();
  updatePetVisibility();
  setTimeout(showPetFirstGuideOnce, 360);
  if (!localStorage.getItem(GUIDE_KEY)) {
    openGuide();
  }
}

function scheduleCategoryRecommendation() {
  const requestId = ++categoryRecommendRequestId;
  if (categoryLockedByUser) return;
  const previous = selectedCategory;
  const local = localRecommendedCategory();
  selectedCategory = local;
  pulseCategoryValue = previous !== selectedCategory ? selectedCategory : null;
  updateCategoryUI();
  Promise.resolve().then(async () => {
    const result = await recommendCategorySmart();
    if (requestId !== categoryRecommendRequestId) return;
    if (categoryLockedByUser) return;
    const before = selectedCategory;
    selectedCategory = result.category;
    pulseCategoryValue = before !== selectedCategory ? selectedCategory : null;
    updateCategoryUI();
  });
}

init();
