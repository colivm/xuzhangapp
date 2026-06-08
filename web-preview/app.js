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
      { max: 5, notes: ["日常地铁通勤出行", "公交短途出行打卡", "选择绿色出行，简单省心", "早班地铁，稳稳到岗", "换乘一小段，通勤完成", "今天的路费，很日常", "刷卡进站，出发啦", "短途公交，省心到家"] },
      { max: 15, notes: ["公交+地铁组合通勤", "下班高峰一段路", "打车到地铁站接驳", "通勤路上买瓶水", "今日出行主打省心", "固定路线，熟悉的感觉", "早晚通勤各记一笔", "城市穿梭的小开销"] },
      { max: 30, notes: ["雨天打车通勤", "加班后打车回家", "共享单车月卡摊销", "停车/充电小费用", "今天路程稍长一点", "通勤多花了一点时间换舒适", "早晚两次出行", "为准时到达的小投资"] },
      { max: 9999, notes: ["跨区通勤长途费", "出差市内交通", "高速/长途客车费", "一次性通勤大额支出", "今天跑了不少路", "行程较满的交通开销", "远距离往返", "为工作奔波的一天"] },
    ],
  },
  {
    id: "food",
    emoji: "🍵",
    label: "吃货专属包",
    category: "餐饮",
    desc: "比如：输入 ¥12，自动备注“晨间咖啡唤醒日常”",
    rules: [
      { max: 15, notes: ["晨间咖啡唤醒日常", "简单饮品放松心情", "随手添置早餐小食", "豆浆包子早餐组合", "午前一杯奶茶小确幸", "便利店轻食补给", "早茶点心小份", "上班前快速吃一口"] },
      { max: 25, notes: ["工作日午餐简餐", "外卖点到工位", "食堂一份热乎饭", "下午茶小点心", "约同事一起简吃", "饱腹又不折腾的一顿", "忙里偷闲喝点什么", "中午好好吃一口"] },
      { max: 40, notes: ["晚餐小聚一份主菜", "周末早午餐放松", "尝试一家新店", "买菜顺路带点卤味", "认真做了一顿家常饭", "犒劳自己的一顿好饭", "热腾腾的面或饭", "今天吃得挺满足"] },
      { max: 9999, notes: ["朋友小聚聚餐", "生日月小小庆祝餐", "想吃了很久的一顿", "节日加菜", "家庭聚餐贡献一道", "品质好一点的一餐", "约会餐厅体验", "美食探店打卡"] },
    ],
  },
  {
    id: "travel",
    emoji: "✈️",
    label: "旅行预算包",
    category: "其他",
    desc: "比如：输入 ¥20，自动备注“短途出行小消费”",
    rules: [
      { max: 20, notes: ["短途出行小消费", "沿途小吃简单打卡", "出行便携物资采购", "景点门口一瓶水", "小城漫步小花费", "街边明信片或小挂件", "公交日票/景区摆渡", "旅途中的轻量补给"] },
      { max: 80, notes: ["展馆/景点门票", "民宿小用品补买", "旅途一顿特色简餐", "城市漫步咖啡歇脚", "伴手礼试吃装", "租车/骑行小时费", "行程里的一笔小惊喜", "路边摊体验打卡"] },
      { max: 200, notes: ["一晚经济型住宿摊销", "城际大巴/高铁一段", "特色餐厅体验", "博物馆联票", "旅行装备小升级", "行程中较充实的一天", "小镇住宿加早午餐", "为风景多走一段路"] },
      { max: 9999, notes: ["机票/高铁主段", "两晚住宿预算", "旅行套餐核心支出", "目的地一日游团", "行李箱/装备购置", "长假出行大项", "带家人出门的一程", "值得记住的一次出发"] },
    ],
  },
  {
    id: "pet",
    emoji: "🐱",
    label: "铲屎官宠物包",
    category: "日用",
    desc: "比如：输入 ¥20，自动备注“给{petName}买了小零食”",
    rules: [
      { max: 20, notes: ["给{petName}买了小零食", "给{petName}安排美味小点心", "补货宠物消耗小用品", "顺手囤一包冻干", "给{petName}挑个小玩具", "猫砂/尿垫补货", "给{petName}加一罐罐头", "毛孩的小零食时间"] },
      { max: 60, notes: ["为{petName}购置口粮用品", "给{petName}囤上爱吃的罐头", "入手小玩具，陪伴{petName}玩耍", "宠物洗护用品补货", "给{petName}买新碗新窝配件", "驱虫药常备补货", "毛孩营养膏一支", "给{petName}添件舒适用品"] },
      { max: 150, notes: ["购入{petName}专用主食与冻干", "安排{petName}日常驱虫护理", "带{petName}洗护美容，清爽干净", "宠物医院常规检查", "换季毛发护理开销", "给{petName}升级主食粮", "宠物保险/会员续费", "大件猫爬架小分期"] },
      { max: 9999, notes: ["带{petName}体检接种疫苗", "添置居家小窝与攀爬家具", "{petName}就医护理相关开销", "为{petName}选购高端营养口粮", "宠物手术/治疗相关", "长途托运或寄养费用", "给{petName}安排年度体检套餐", "毛孩的大件生活升级"] },
    ],
  },
];
const CATEGORY_AI_ENDPOINT = "http://localhost:8787/v1/category/recommend";
const INSIGHT_AI_ENDPOINT = "http://localhost:8787/v1/insight/daily";
const AI_PROXY_TOKEN_STORAGE_KEY = "qingzhang_ai_proxy_token";
const AI_USER_TOKEN_STORAGE_KEY = "qingzhang_ai_user_token";
const AI_MODEL_STORAGE_KEY = "qingzhang_ai_model";
const AI_TIMEOUT_MS_STORAGE_KEY = "qingzhang_ai_timeout_ms";
const DEFAULT_AI_MODEL = "doubao-seed-1-6-flash-250828";
const DEFAULT_AI_TIMEOUT_MS = 15000;
const PERIOD_TIMEOUT_MS = {
  daily: 15000,
  weekly: 22000,
  monthly: 35000,
};
const DEBUG_UI_ENABLED = false;
const UI_TABS = new Set(["home", "record", "stats", "insight", "settings"]);
const UI_MODALS = new Set(["none", "guide", "account", "ocrConfirm", "ocrCategory", "monthlyTrial", "billDateRange", "deleteConfirm", "billPlayback"]);
const UI_INPUT_FOCUS = new Set(["none", "amount", "title"]);
const ERROR_LOG_KEY = "qingzhang_runtime_errors_v1";
const ANALYTICS_KEY = "qingzhang_product_analytics_v1";
const ANALYTICS_MAX_EVENTS = 1000;
const MEMBER_NUDGE_POLICY_KEY = "qingzhang_member_nudge_policy_v1";
const MEMBER_NUDGE_STATE_KEY = "qingzhang_member_nudge_state_v1";
const DEFAULT_MEMBER_NUDGE_POLICY = {
  mode: "debug", // debug | prod
  debugCooldownMs: 90 * 1000,
  prodDailyLimit: 1,
  prodSceneCooldownDays: 7,
};
const AI_GLOBAL_STYLE_PROMPT =
  "你是治愈系记账陪伴助手，全程温柔平和，绝不评判、不指责、不劝省钱、不说教、不制造消费焦虑。只客观总结支出结构、消费偏好、生活节奏；多用正向、治愈、生活化语句。禁止词汇：超支、浪费、克制、理性消费、减少、控制、不必要、节约。按要求严格控制字数，段落清爽，语气柔软治愈。";
const AI_COPY_LIMITS = {
  daily: { min: 35, max: 45 },
  weekly: { min: 70, max: 90 },
  monthly: { min: 120, max: 150 },
};
const AI_FORBIDDEN_WORDS = [
  "超支",
  "浪费",
  "克制",
  "理性消费",
  "减少",
  "压缩",
  "控制",
  "节制",
  "不必要",
  "节约",
  "纠正",
  "管控",
];
const AI_SOFT_REPLACEMENTS = {
  超支: "开销波动",
  浪费: "支出选择",
  克制: "放松看待",
  理性消费: "按自己节奏安排",
  减少: "慢慢留意",
  压缩: "温和调整",
  控制: "从容安排",
  节制: "轻松平衡",
  不必要: "可选开销",
  节约: "更从容",
  纠正: "回看",
  管控: "整理",
};

const MEMBER_BENEFITS = [
  {
    title: "🎬 周/月生活切片无限回看",
    desc: "统计页「本周生活切片」「本月生活章」不限次数播放；用章节卡片看懂这段时间花了什么、节奏如何。核心卖点。",
  },
  {
    title: "📝 场景备注包 + 宠物专属昵称",
    desc: "通勤/吃货/宠物/旅行四包一键备注；自定义昵称（2～6 字）贯穿切片与记账旁白。",
  },
  {
    title: "📷 OCR 智能识票不限次",
    desc: "拍照导入账单；免费用户每日 3 次尝鲜，会员不限（可设软上限防滥用，商店仍写「不限」）。",
  },
  {
    title: "☁️ 云端备份 + 纯净无广告",
    desc: "登录后账单可同步云端、换机不丢；全程无营销弹窗。天气/季节暖心旁白加强随会员模板更完整。",
  },
  {
    title: "💬 小 AI 说 · 播后可选深聊（不限次）",
    desc: "生活切片讲完后，若想多一句交谈式建议再用；含季/年深度复盘（需 ai-proxy 会员 JWT）。增强项，非首图卖点。",
  },
];

const MEMBER_FREE_QUOTA_FOOTNOTE =
  "免费体验：本周生活切片每自然周 1 次 · 本月生活章终生 3 次 · OCR 每日 3 次 · 今日流水回放每日 1 次。开通会员后上述回访与识票不限。";
const HOT_WEATHER_THRESHOLD_C = 30;
const MONTH_END_START_DAY = 26;
const MONTH_EXPENSE_SOFT_THRESHOLD = 3500;
const COOLING_EXPENSE_KEYWORDS = [
  "奶茶",
  "咖啡",
  "饮料",
  "果茶",
  "柠檬茶",
  "西瓜",
  "冰淇淋",
  "雪糕",
  "冰棍",
  "冰粉",
  "甜品",
  "气泡水",
  "冷饮",
  "冰美式",
  "冰拿铁",
  "水果",
];
const PET_HIDE_SESSION_KEY = "qingzhang_pet_hidden_session";
const PET_FIRST_GUIDE_KEY = "qingzhang_pet_first_guide_shown_v1";
const WEATHER_HINT_COOLDOWN_KEY = "qingzhang_weather_hint_cooldown_v1";
const WEATHER_AI_PET_COOLDOWN_KEY = "qingzhang_weather_ai_pet_cooldown_v1";
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
    hotNoCool: [
      "今天好热呀～要不要奖励自己一杯小饮料呢？",
      "外面热乎乎的，{petName}想提醒你：来点清凉小快乐也不错呀。",
      "天气这么热，给自己安排一份清爽小补给吧，我举爪支持你～",
    ],
    rainyHome: [
      "外面在下雨，今天在家慢慢待着也很治愈，给自己一点松弛感吧。",
      "雨天最适合把节奏放慢，{petName}陪你把今天过得软乎乎的。",
      "下雨天就别赶路啦，窝在舒服的小角落里，也是一种温柔生活。",
    ],
    monthEndSoft: [
      "快到月末啦，这个月你已经很认真记录了，接下来慢慢花、慢慢过就很好。",
      "月末节奏稍快也没关系，{petName}陪你把日子过稳稳的，不着急。",
      "这个月辛苦啦，月末给自己一点从容感，按你的节奏继续就很棒。",
    ],
    weekendHealing: [
      "周末到啦，今天就轻松一点，去做一件让自己开心的小事吧。",
      "周末是补充能量的好时候，花点小钱换一点松弛感，也很值得。",
      "难得周末，记账继续，快乐也继续，{petName}陪你慢慢享受生活。",
    ],
    noExpenseCalm: [
      "今天还没花钱也没关系，按自己的节奏生活就很好，{petName}在这儿陪你。",
      "今天像一口慢慢呼吸的空气，没消费也很正常，舒服就好。",
    ],
    commuteSteady: [
      "今天通勤开销很稳定，你的生活节奏真的很有秩序感。",
      "这几笔出行花费都很日常，稳稳当当地过日子就很安心。",
    ],
    groceryWarm: [
      "今天把生活小补给安排得很好，柴米油盐也是被认真照顾的温柔。",
      "这些日用和餐饮花费很踏实，日子被你收拾得暖暖的。",
    ],
    highSpendComfort: [
      "今天花得稍微多一点也没关系，重要的是你有在认真记录和感受生活。",
      "偶尔高一点的开销很正常，{petName}陪你慢慢把节奏找回来就好。",
    ],
  },
  weatherAiFallback: [
    "今天的天气和你的消费节奏都很温和，{petName}觉得你把日子安排得刚刚好。",
    "我看了看今天的花费和天气，整体都很稳，按这个节奏生活就很舒服。",
    "不管晴天还是阴天，你今天的每一笔都很踏实，慢慢记录就会更安心。",
    "今天的消费主要在日常刚需，天气也很配合，{petName}继续陪你轻松记账。",
  ],
  aiReview: [
    "复盘完啦，你这个月的消费节奏很稳！",
    "分析完啦，你比上个月更了解自己的钱了呢～",
    "别担心，复盘不是为了批评你，而是为了让你花得更轻松。",
    "数据不会骗你，但也别苛责自己，保持这个节奏就很好。",
  ],
  streak: ["已经坚持 {days} 天啦，你离目标越来越近了！", "连续记录 {days} 天，习惯正在长出来！"],
};
const pageTitles = {
  home: "今日",
  record: "记一笔",
  stats: "看看花",
  insight: "小 AI 说",
  settings: "我的小窝",
};

const PET_SCENE_RULES = [
  {
    id: "hotNoCool",
    key: "hotNoCool",
    match: ({ weather }) => Number.isFinite(weather?.temp) && weather.temp >= HOT_WEATHER_THRESHOLD_C && !hasCoolingExpenseToday(),
  },
  {
    id: "rainyHome",
    key: "rainyHome",
    match: ({ weather }) => isRainyWeatherCode(weather?.weatherCode),
  },
  {
    id: "monthEndSoft",
    key: "monthEndSoft",
    match: ({ recordLike }) => hasMonthExpensePressure(recordLike),
  },
  {
    id: "weekendHealing",
    key: "weekendHealing",
    match: ({ recordLike }) => isWeekend(recordLike?.createdAt),
  },
  {
    id: "commuteSteady",
    key: "commuteSteady",
    match: () => commuteExpenseCountToday() >= 2,
  },
  {
    id: "groceryWarm",
    key: "groceryWarm",
    match: () => hasGroceryExpenseToday(),
  },
  {
    id: "highSpendComfort",
    key: "highSpendComfort",
    match: () => todayExpenseTotal() >= 300,
  },
  {
    id: "noExpenseCalm",
    key: "noExpenseCalm",
    match: () => todayExpenseTotal() <= 0,
  },
];

const defaultState = {
  settings: {
    displayName: "叙帐用户",
    appearance: "system",
    syncEnabled: false,
    remoteAIEnabled: false,
    isMember: false,
    memberTier: "",
    isLoggedIn: false,
    userPetNickname: "",
    petCompanionEnabled: true,
    weatherCompanionEnabled: false,
  },
  recordMode: "manual",
  period: "month",
  billCustomRangeStart: "",
  billCustomRangeEnd: "",
  items: [],
  insights: [],
  monthlyInsights: [],
  latestActionCard: null,
  weeklyActionCard: "",
  monthlyActionCard: "",
  monthlyTrialUsed: 0,
  isGeneratingInsight: false,
  isGeneratingMonthlyInsight: false,
};

const refs = {
  content: document.querySelector(".content"),
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
  homeStoryTitle: document.getElementById("homeStoryTitle"),
  homeStorySubtitle: document.getElementById("homeStorySubtitle"),
  homePlaybackEntryBtn: document.getElementById("homePlaybackEntryBtn"),
  homePlaybackEntryHint: document.getElementById("homePlaybackEntryHint"),
  todayTotal: document.getElementById("todayTotal"),
  weekTotal: document.getElementById("weekTotal"),
  homeTodayList: document.getElementById("homeTodayList"),
  homeTodayEmptyArt: document.getElementById("homeTodayEmptyArt"),
  homeInsightSummary: document.getElementById("homeInsightSummary"),
  homeInsightHint: document.getElementById("homeInsightHint"),
  homeActionCard: document.getElementById("homeActionCard"),
  homeActionCardMeta: document.getElementById("homeActionCardMeta"),
  homeActionCardText: document.getElementById("homeActionCardText"),
  petWidget: document.getElementById("petWidget"),
  petBtn: document.getElementById("petBtn"),
  petBubble: document.getElementById("petBubble"),
  petCompanionSwitch: document.getElementById("petCompanionSwitch"),
  weatherCompanionRow: document.getElementById("weatherCompanionRow"),
  weatherCompanionSwitch: document.getElementById("weatherCompanionSwitch"),
  weatherCompanionHelper: document.getElementById("weatherCompanionHelper"),
  weatherNeutralRow: document.getElementById("weatherNeutralRow"),
  weatherNeutralSwitch: document.getElementById("weatherNeutralSwitch"),
  weatherNeutralHelper: document.getElementById("weatherNeutralHelper"),
  memberNudgeBar: document.getElementById("memberNudgeBar"),
  memberNudgeText: document.getElementById("memberNudgeText"),
  memberNudgeBtn: document.getElementById("memberNudgeBtn"),
  memberNudgeDismissBtn: document.getElementById("memberNudgeDismissBtn"),
  recordModeSegment: document.getElementById("recordModeSegment"),
  modeButtons: [...document.querySelectorAll(".mode-btn")],
  manualForm: document.getElementById("manualForm"),
  ocrForm: document.getElementById("ocrForm"),
  recordFormTitle: document.getElementById("recordFormTitle"),
  amountStage: document.getElementById("amountStage"),
  lifeEntryPreview: document.getElementById("lifeEntryPreview"),
  lifeEntryHeadline: document.getElementById("lifeEntryHeadline"),
  lifeEntryAmount: document.getElementById("lifeEntryAmount"),
  lifeEntryEmotion: document.getElementById("lifeEntryEmotion"),
  lifeEntryMeta: document.getElementById("lifeEntryMeta"),
  lifeEntryQuickActions: document.getElementById("lifeEntryQuickActions"),
  recordPrimaryActions: document.getElementById("recordPrimaryActions"),
  recordDetailsFold: document.getElementById("recordDetailsFold"),
  recordDetailsToggle: document.getElementById("recordDetailsToggle"),
  recordDetailsToggleHint: document.getElementById("recordDetailsToggleHint"),
  recordDetailsBody: document.getElementById("recordDetailsBody"),
  prefillDemoBar: document.getElementById("prefillDemoBar"),
  prefillDemoButtons: [...document.querySelectorAll("[data-prefill-mode]")],
  amountInput: document.getElementById("amountInput"),
  amountDisplay: document.getElementById("amountDisplay"),
  amountQuickKeyboard: document.getElementById("amountQuickKeyboard"),
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
  billDateFilterBtn: document.getElementById("billDateFilterBtn"),
  billCategoryFilter: document.getElementById("billCategoryFilter"),
  billExpenseTotal: document.getElementById("billExpenseTotal"),
  billRecordsList: document.getElementById("billRecordsList"),
  billRecordsEmpty: document.getElementById("billRecordsEmpty"),
  billTrendLine: document.getElementById("billTrendLine"),
  billTrendMaxLabel: document.getElementById("billTrendMaxLabel"),
  billTrendStartLabel: document.getElementById("billTrendStartLabel"),
  billTrendEndLabel: document.getElementById("billTrendEndLabel"),
  billTrendPeakDot: document.getElementById("billTrendPeakDot"),
  billTrendPeakLabel: document.getElementById("billTrendPeakLabel"),
  billTrendInsight: document.getElementById("billTrendInsight"),
  monthlyTrialText: document.getElementById("monthlyTrialText"),
  generateMonthlyInsightBtn: document.getElementById("generateMonthlyInsightBtn"),
  monthlyAIStatus: document.getElementById("monthlyAIStatus"),
  monthlyInsightContent: document.getElementById("monthlyInsightContent"),
  monthlyInsightSummary: document.getElementById("monthlyInsightSummary"),
  monthlyInsightStructure: document.getElementById("monthlyInsightStructure"),
  monthlyInsightAdvice: document.getElementById("monthlyInsightAdvice"),
  monthlySoftPlanBtn: document.getElementById("monthlySoftPlanBtn"),
  monthlySaveSummaryBtn: document.getElementById("monthlySaveSummaryBtn"),
  monthlyToneSwitchBtn: document.getElementById("monthlyToneSwitchBtn"),
  advancedInsightToggleBtn: document.getElementById("advancedInsightToggleBtn"),
  advancedInsightActions: document.getElementById("advancedInsightActions"),
  monthlyTrialModal: document.getElementById("monthlyTrialModal"),
  monthlyTrialModalTitle: document.getElementById("monthlyTrialModalTitle"),
  monthlyTrialModalBody: document.getElementById("monthlyTrialModalBody"),
  monthlyTrialModalOkBtn: document.getElementById("monthlyTrialModalOkBtn"),
  monthlyTrialUpgradeBtn: document.getElementById("monthlyTrialUpgradeBtn"),
  deleteConfirmModal: document.getElementById("deleteConfirmModal"),
  deleteConfirmCancelBtn: document.getElementById("deleteConfirmCancelBtn"),
  deleteConfirmOkBtn: document.getElementById("deleteConfirmOkBtn"),
  billDateRangeModal: document.getElementById("billDateRangeModal"),
  billDateRangeCloseBtn: document.getElementById("billDateRangeCloseBtn"),
  billPresetWeekBtn: document.getElementById("billPresetWeekBtn"),
  billPresetMonthBtn: document.getElementById("billPresetMonthBtn"),
  billPresetYearBtn: document.getElementById("billPresetYearBtn"),
  billDateRangeStartInput: document.getElementById("billDateRangeStartInput"),
  billDateRangeEndInput: document.getElementById("billDateRangeEndInput"),
  billDateRangeConfirmBtn: document.getElementById("billDateRangeConfirmBtn"),
  billPlaybackModal: document.getElementById("billPlaybackModal"),
  billPlaybackCloseBtn: document.getElementById("billPlaybackCloseBtn"),
  billPlaybackTimeline: document.getElementById("billPlaybackTimeline"),
  billPlaybackProgressBar: document.getElementById("billPlaybackProgressBar"),
  billPlaybackDoneText: document.getElementById("billPlaybackDoneText"),
  billPlaybackPauseBtn: document.getElementById("billPlaybackPauseBtn"),
  billPlaybackRestartBtn: document.getElementById("billPlaybackRestartBtn"),
  generateQuarterlyInsightBtn: document.getElementById("generateQuarterlyInsightBtn"),
  generateYearlyInsightBtn: document.getElementById("generateYearlyInsightBtn"),
  insightSummary: document.getElementById("insightSummary"),
  insightAction: document.getElementById("insightAction"),
  insightEncourage: document.getElementById("insightEncourage"),
  weeklyRhythmBtn: document.getElementById("weeklyRhythmBtn"),
  weeklyShareBtn: document.getElementById("weeklyShareBtn"),
  weeklyTagBtn: document.getElementById("weeklyTagBtn"),
  insightHistory: document.getElementById("insightHistory"),
  insightHistoryEmpty: document.getElementById("insightHistoryEmpty"),
  generateInsightBtn: document.getElementById("generateInsightBtn"),
  dailyAIStatus: document.getElementById("dailyAIStatus"),
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
  accountPetNameFeedback: document.getElementById("accountPetNameFeedback"),
  accountCenterName: document.getElementById("accountCenterName"),
  accountCenterState: document.getElementById("accountCenterState"),
  accountPetNicknameInput: document.getElementById("accountPetNicknameInput"),
  accountPetNicknameSaveBtn: document.getElementById("accountPetNicknameSaveBtn"),
  accountPetNicknameTip: document.getElementById("accountPetNicknameTip"),
  accountUpgradeEntryBtn: document.getElementById("accountUpgradeEntryBtn"),
  accountCenterBenefitsTitle: document.getElementById("accountCenterBenefitsTitle"),
  accountCenterBenefitsLead: document.getElementById("accountCenterBenefitsLead"),
  accountCenterBenefitsList: document.getElementById("accountCenterBenefitsList"),
  accountMemberView: document.getElementById("accountMemberView"),
  accountMemberBackBtn: document.getElementById("accountMemberBackBtn"),
  accountMemberHeroTitle: document.getElementById("accountMemberHeroTitle"),
  accountMemberHeroIntro: document.getElementById("accountMemberHeroIntro"),
  accountQuickBuyBtn: document.getElementById("accountQuickBuyBtn"),
  accountQuickBuyTip: document.getElementById("accountQuickBuyTip"),
  accountMorePlansToggle: document.getElementById("accountMorePlansToggle"),
  accountMorePlansBody: document.getElementById("accountMorePlansBody"),
  accountMemberBenefitsToggle: document.getElementById("accountMemberBenefitsToggle"),
  accountMemberBenefitsBody: document.getElementById("accountMemberBenefitsBody"),
  accountMemberBenefitsList: document.getElementById("accountMemberBenefitsList"),
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
let petActionTimer = null;
let scenePackExpanded = false;
let prefillDemoMode = "generic";
let recordDetailsExpanded = false;
let weatherGeo = null;
let weatherSnapshot = null;
let isRequestingWeatherPermission = false;
let weatherRefreshTimer = null;
let accountOverlayView = "login";
let memberCtaContext = "default";
let memberNudgeLastAt = 0;
let memberPlansExpanded = false;
let memberOverlayExposureMark = "";
let pageTitleFadeTimer = null;
let billRangeDraftMode = "month";
let pendingDeleteRecordId = null;
let advancedInsightExpanded = false;
let playbackRafId = null;
let playbackStartAt = 0;
let playbackElapsedBeforePause = 0;
let playbackActiveIndex = -1;
let playbackRecords = [];
let playbackRunning = false;
const uiRuntimeState = {
  tab: "home",
  modal: "none",
  inputFocus: "none",
};
let aiRunStatus = {
  daily: { mode: "hidden", text: "" },
  monthly: { mode: "hidden", text: "" },
  premium: { mode: "hidden", text: "" },
};

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
      latestActionCard:
        parsed.latestActionCard && typeof parsed.latestActionCard.text === "string"
          ? {
              text: parsed.latestActionCard.text,
              updatedAt: parsed.latestActionCard.updatedAt || "",
              scope: parsed.latestActionCard.scope || "none",
            }
          : null,
    };
  } catch {
    return structuredClone(defaultState);
  }
}

function setLatestActionCard(text, { scope = "none" } = {}) {
  const cleanText = String(text || "").trim();
  if (!cleanText) return;
  state.latestActionCard = {
    text: cleanText,
    updatedAt: new Date().toISOString(),
    scope: scope === "weekly" || scope === "monthly" ? scope : "none",
  };
}

function getActionCardExpiryDays(scope) {
  if (scope === "weekly") return 7;
  if (scope === "monthly") return 30;
  return 0;
}

function isLatestActionCardExpired(card) {
  if (!card || !card.updatedAt) return false;
  const expiryDays = getActionCardExpiryDays(card.scope);
  if (!expiryDays) return false;
  const updatedTs = new Date(card.updatedAt).getTime();
  if (!Number.isFinite(updatedTs)) return false;
  return Date.now() - updatedTs >= expiryDays * 24 * 60 * 60 * 1000;
}

function formatRelativeTime(isoText) {
  if (!isoText) return "";
  const ts = new Date(isoText).getTime();
  if (!Number.isFinite(ts)) return "";
  const diffMs = Date.now() - ts;
  if (diffMs < 45 * 1000) return "刚刚更新";
  const diffMin = Math.floor(diffMs / 60000);
  if (diffMin < 60) return `${diffMin} 分钟前更新`;
  const diffHour = Math.floor(diffMin / 60);
  if (diffHour < 24) return `${diffHour} 小时前更新`;
  const diffDay = Math.floor(diffHour / 24);
  return `${diffDay} 天前更新`;
}

function syncOverlayScrollLock() {
  const overlays = [
    refs.accountOverlay,
    refs.guideOverlay,
    refs.ocrConfirmOverlay,
    refs.ocrCategoryOverlay,
    refs.monthlyTrialModal,
    refs.billDateRangeModal,
    refs.deleteConfirmModal,
    refs.billPlaybackModal,
  ];
  const hasVisibleOverlay = overlays.some((el) => el && !el.classList.contains("hidden"));
  document.body.classList.toggle("modal-open", hasVisibleOverlay);
  refs.content?.classList.toggle("locked", hasVisibleOverlay);
}

function watchOverlayChanges() {
  const overlays = [
    refs.accountOverlay,
    refs.guideOverlay,
    refs.ocrConfirmOverlay,
    refs.ocrCategoryOverlay,
    refs.monthlyTrialModal,
    refs.billDateRangeModal,
    refs.deleteConfirmModal,
    refs.billPlaybackModal,
  ].filter(Boolean);
  overlays.forEach((el) => {
    const observer = new MutationObserver(() => syncOverlayScrollLock());
    observer.observe(el, { attributes: true, attributeFilter: ["class"] });
  });
  syncOverlayScrollLock();
}

function setAIStatus(slot, mode, text) {
  aiRunStatus[slot] = { mode, text };
}

function renderAIStatus() {
  const apply = (el, status) => {
    if (!el) return;
    el.classList.remove("live", "fallback", "error");
    if (!status || status.mode === "hidden") {
      el.classList.add("hidden");
      el.textContent = "";
      return;
    }
    el.textContent = status.text;
    el.classList.remove("hidden");
    el.classList.add(status.mode);
  };
  apply(refs.dailyAIStatus, aiRunStatus.daily);
  apply(refs.monthlyAIStatus, aiRunStatus.premium.mode !== "hidden" ? aiRunStatus.premium : aiRunStatus.monthly);
}

function persist() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function getMemberNudgePolicy() {
  try {
    const raw = localStorage.getItem(MEMBER_NUDGE_POLICY_KEY);
    if (!raw) return { ...DEFAULT_MEMBER_NUDGE_POLICY };
    const parsed = JSON.parse(raw);
    return {
      ...DEFAULT_MEMBER_NUDGE_POLICY,
      ...parsed,
      mode: parsed?.mode === "prod" ? "prod" : "debug",
    };
  } catch {
    return { ...DEFAULT_MEMBER_NUDGE_POLICY };
  }
}

function setMemberNudgePolicy(partial = {}) {
  const next = { ...getMemberNudgePolicy(), ...partial };
  if (next.mode !== "debug" && next.mode !== "prod") next.mode = "debug";
  try {
    localStorage.setItem(MEMBER_NUDGE_POLICY_KEY, JSON.stringify(next));
  } catch {
    // Ignore policy write errors in preview mode.
  }
  return next;
}

function resolveDefaultNudgeModeByEnv() {
  try {
    if (typeof window === "undefined" || !window.location) return "debug";
    if (window.location.protocol === "file:") return "debug";
    const host = String(window.location.hostname || "").toLowerCase();
    if (host === "localhost" || host === "127.0.0.1" || host === "::1") return "debug";
    return "prod";
  } catch {
    return "debug";
  }
}

function ensureMemberNudgePolicyForEnv() {
  try {
    if (localStorage.getItem(MEMBER_NUDGE_POLICY_KEY)) return;
    setMemberNudgePolicy({ mode: resolveDefaultNudgeModeByEnv() });
  } catch {
    // Ignore storage failures in preview mode.
  }
}

function getMemberNudgeState() {
  try {
    const raw = localStorage.getItem(MEMBER_NUDGE_STATE_KEY);
    const parsed = raw ? JSON.parse(raw) : {};
    return {
      lastShownAt: Number(parsed.lastShownAt || 0),
      dailyDayKey: String(parsed.dailyDayKey || ""),
      dailyCount: Number(parsed.dailyCount || 0),
      sceneCooldownUntil: typeof parsed.sceneCooldownUntil === "object" && parsed.sceneCooldownUntil
        ? parsed.sceneCooldownUntil
        : {},
    };
  } catch {
    return { lastShownAt: 0, dailyDayKey: "", dailyCount: 0, sceneCooldownUntil: {} };
  }
}

function setMemberNudgeState(next) {
  try {
    localStorage.setItem(MEMBER_NUDGE_STATE_KEY, JSON.stringify(next));
  } catch {
    // Ignore nudge state write errors in preview mode.
  }
}

function getTodayKey() {
  return new Date().toISOString().slice(0, 10);
}

function canShowMemberNudge(context = "default") {
  if (state.settings.isMember) return false;
  const policy = getMemberNudgePolicy();
  const nudgeState = getMemberNudgeState();
  const now = Date.now();
  if (policy.mode === "debug") {
    return now - nudgeState.lastShownAt >= Number(policy.debugCooldownMs || 90 * 1000);
  }
  const dayKey = getTodayKey();
  if (nudgeState.dailyDayKey === dayKey && nudgeState.dailyCount >= Number(policy.prodDailyLimit || 1)) {
    return false;
  }
  const until = Number(nudgeState.sceneCooldownUntil?.[context] || 0);
  if (until > now) return false;
  return true;
}

function markMemberNudgeShown(context = "default") {
  const policy = getMemberNudgePolicy();
  const nudgeState = getMemberNudgeState();
  const now = Date.now();
  nudgeState.lastShownAt = now;
  if (policy.mode === "prod") {
    const dayKey = getTodayKey();
    if (nudgeState.dailyDayKey !== dayKey) {
      nudgeState.dailyDayKey = dayKey;
      nudgeState.dailyCount = 1;
    } else {
      nudgeState.dailyCount += 1;
    }
  }
  setMemberNudgeState(nudgeState);
}

function markMemberNudgeDismissed(context = "default") {
  const policy = getMemberNudgePolicy();
  if (policy.mode !== "prod") return;
  const nudgeState = getMemberNudgeState();
  const cooldownMs = Number(policy.prodSceneCooldownDays || 7) * 24 * 60 * 60 * 1000;
  nudgeState.sceneCooldownUntil = {
    ...nudgeState.sceneCooldownUntil,
    [context]: Date.now() + cooldownMs,
  };
  setMemberNudgeState(nudgeState);
}

function readAnalyticsEvents() {
  try {
    const raw = localStorage.getItem(ANALYTICS_KEY);
    const parsed = raw ? JSON.parse(raw) : [];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeAnalyticsEvents(events) {
  try {
    localStorage.setItem(ANALYTICS_KEY, JSON.stringify(events.slice(0, ANALYTICS_MAX_EVENTS)));
  } catch {
    // Ignore analytics write errors to avoid impacting UX.
  }
}

function trackAnalytics(event, props = {}) {
  const payload = {
    event,
    props,
    at: new Date().toISOString(),
    tab: currentTab,
    petMode: Boolean(state.settings.petCompanionEnabled),
    member: Boolean(state.settings.isMember),
  };
  const events = readAnalyticsEvents();
  events.unshift(payload);
  writeAnalyticsEvents(events);
}

function getAnalyticsSummary(lastDays = 7) {
  const events = readAnalyticsEvents();
  const start = new Date();
  start.setDate(start.getDate() - Math.max(0, Number(lastDays || 0) - 1));
  start.setHours(0, 0, 0, 0);
  const recent = events.filter((item) => new Date(item.at) >= start);
  const byEvent = {};
  recent.forEach((item) => {
    byEvent[item.event] = (byEvent[item.event] || 0) + 1;
  });
  return {
    window_days: lastDays,
    event_count: recent.length,
    by_event: byEvent,
  };
}

function showToast(message) {
  refs.toast.textContent = message;
  refs.toast.classList.remove("hidden");
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => {
    refs.toast.classList.add("hidden");
  }, 1600);
}

function reportRuntimeError(scope, error) {
  const entry = {
    scope,
    message: error?.message || String(error),
    stack: error?.stack || "",
    at: new Date().toISOString(),
  };
  try {
    const raw = localStorage.getItem(ERROR_LOG_KEY);
    const logs = raw ? JSON.parse(raw) : [];
    logs.unshift(entry);
    localStorage.setItem(ERROR_LOG_KEY, JSON.stringify(logs.slice(0, 20)));
  } catch {
    // Ignore storage write failure; console logging below is the fallback.
  }
  console.error(`[safeRender:${scope}]`, error);
}

function safeRender(scope, runner, { toastMessage = "页面刚刚有点卡，我已经自动恢复了。" } = {}) {
  try {
    return runner();
  } catch (error) {
    reportRuntimeError(scope, error);
    if (toastMessage) showToast(toastMessage);
    return null;
  }
}

function setUITab(tab) {
  if (!UI_TABS.has(tab)) return;
  uiRuntimeState.tab = tab;
}

function setUIModal(modal) {
  if (!UI_MODALS.has(modal)) return;
  uiRuntimeState.modal = modal;
}

function setUIInputFocus(target) {
  if (!UI_INPUT_FOCUS.has(target)) return;
  uiRuntimeState.inputFocus = target;
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

function resetAppScroll() {
  refs.content?.scrollTo({ top: 0, left: 0, behavior: "auto" });
  if (refs.content) refs.content.scrollTop = 0;
  window.scrollTo({ top: 0, left: 0, behavior: "auto" });
  document.documentElement.scrollTop = 0;
  document.body.scrollTop = 0;
}

function enforceTopScrollAfterTabSwitch() {
  resetAppScroll();
  requestAnimationFrame(() => {
    resetAppScroll();
    requestAnimationFrame(() => {
      resetAppScroll();
    });
  });
  setTimeout(() => {
    resetAppScroll();
  }, 120);
}

function switchTab(tab) {
  if (!UI_TABS.has(tab)) return;
  const prevTab = currentTab;
  if (prevTab === "record" && tab !== "record") {
    refs.amountInput?.blur();
    document.querySelector(".app-shell")?.classList.remove("keyboard-active");
  }
  currentTab = tab;
  setUITab(tab);
  Object.keys(refs.pages).forEach((key) => refs.pages[key].classList.toggle("active", key === tab));
  refs.tabs.forEach((btn) => btn.classList.toggle("active", btn.dataset.tab === tab));
  if (prevTab !== tab) {
    enforceTopScrollAfterTabSwitch();
  }
  const nextTitle = pageTitles[tab];
  if (refs.pageTitle && nextTitle) {
    if (prevTab !== tab) {
      refs.pageTitle.style.opacity = "0.38";
      clearTimeout(pageTitleFadeTimer);
      pageTitleFadeTimer = setTimeout(() => {
        refs.pageTitle.textContent = nextTitle;
        requestAnimationFrame(() => {
          refs.pageTitle.style.opacity = "1";
        });
      }, 100);
    } else {
      refs.pageTitle.textContent = nextTitle;
    }
  }
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
    }, 140);
  }
  updateDebugHUD(`switch:${tab}`);
}

function forceGoHomeTab() {
  currentTab = "home";
  setUITab("home");
  Object.keys(refs.pages).forEach((key) => refs.pages[key].classList.toggle("active", key === "home"));
  refs.tabs.forEach((btn) => btn.classList.toggle("active", btn.dataset.tab === "home"));
  if (refs.pageTitle) refs.pageTitle.textContent = pageTitles.home;
  updatePetVisibility();
  enforceTopScrollAfterTabSwitch();
  updateDebugHUD("force-home");
}

function goHomeAfterSave() {
  refs.amountInput?.blur();
  document.querySelector(".app-shell")?.classList.remove("keyboard-active");
  switchTab("home");
  render();
  requestAnimationFrame(() => forceGoHomeTab());
  setTimeout(() => forceGoHomeTab(), 120);
  updateDebugHUD("save-go-home");
}

function ensureDebugHUD() {
  if (!DEBUG_UI_ENABLED) return null;
  let hud = document.getElementById("debugHud");
  if (hud) return hud;
  hud = document.createElement("div");
  hud.id = "debugHud";
  hud.style.position = "fixed";
  hud.style.top = "10px";
  hud.style.right = "10px";
  hud.style.zIndex = "9999";
  hud.style.padding = "6px 8px";
  hud.style.borderRadius = "10px";
  hud.style.background = "rgba(20,20,20,0.72)";
  hud.style.color = "#fff";
  hud.style.fontSize = "11px";
  hud.style.lineHeight = "1.35";
  hud.style.whiteSpace = "pre-line";
  hud.style.maxWidth = "74vw";
  hud.style.pointerEvents = "none";
  document.body.appendChild(hud);
  return hud;
}

function updateDebugHUD(trigger = "") {
  if (!DEBUG_UI_ENABLED) return;
  const hud = ensureDebugHUD();
  if (!hud) return;
  const activePage =
    Object.entries(refs.pages).find(([, el]) => el?.classList.contains("active"))?.[0] || "none";
  const activeTab = refs.tabs.find((btn) => btn.classList.contains("active"))?.dataset.tab || "none";
  const listCount = refs.billRecordsList?.children?.length || 0;
  const emptyShown = refs.billRecordsEmpty ? getComputedStyle(refs.billRecordsEmpty).display !== "none" : false;
  hud.textContent = [
    `trigger: ${trigger || "-"}`,
    `currentTab: ${currentTab} | activePage: ${activePage} | activeTab: ${activeTab}`,
    `period: ${state.period} | items: ${state.items.length} | billList: ${listCount} | empty: ${emptyShown}`,
  ].join("\n");
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

function isPetModeActive() {
  return Boolean(state.settings.petCompanionEnabled);
}

function getExperienceCopy() {
  if (isPetModeActive()) {
    return {
      homeInsightEmpty: "记几笔账，明天来这里看 AI 给你的专属小结。",
      dailyNudge: "花 10 秒，轻松记一笔",
      dailyInsightEmpty: "还没有今日复盘。",
      dailyHistoryTag: "每日建议",
      weeklyHistoryTag: "近7天复盘",
      insightBtnIdle: "换个轻读版本",
      insightBtnLoading: "正在准备轻读…",
      monthlyBtnIdle: "生成月度复盘",
      monthlyBtnLoading: "正在生成月度复盘...",
      monthlyBtnLocked: '<span class="lock-icon">🔒︎</span>生成月度复盘',
    };
  }
  return {
    homeInsightEmpty: "记录几笔账单后，这里会自动生成今日小结。",
    dailyNudge: "花 10 秒，完成一条记录",
    dailyInsightEmpty: "还没有今日小结。",
    dailyHistoryTag: "今日小结",
    weeklyHistoryTag: "近7天分析",
    insightBtnIdle: "换个轻读版本",
    insightBtnLoading: "正在准备轻读…",
    monthlyBtnIdle: "生成月度分析",
    monthlyBtnLoading: "正在生成月度分析...",
    monthlyBtnLocked: '<span class="lock-icon">🔒︎</span>生成月度分析',
  };
}

function getAIStatusText(statusKind) {
  const petMode = isPetModeActive();
  const petCopyText = {
    live: "AI 在线，实时分析中",
    error: "本地计算，AI 服务忙，稍后再试",
    fallback: "本地兜底，稳定可用",
  };
  const neutralCopyText = {
    live: "AI 在线，已完成实时分析",
    error: "本地计算，服务繁忙，已切换离线结果",
    fallback: "本地结果可用，分析已完成",
  };
  const textMap = petMode ? petCopyText : neutralCopyText;
  return textMap[statusKind] || "";
}

function getToastCopy() {
  if (isPetModeActive()) {
    return {
      insightGenerated: (label) => `${label}已生成`,
      weatherOff: "已关闭天气/季节场景提醒",
      weatherOn: "天气/季节场景提醒已开启",
      weatherDenied: "未获取定位权限，仍使用通用温柔文案",
      loginSuccess: "登录成功，已解锁账号同步入口",
      upgradeSuccess: (planName) => `${planName}开通成功，已解锁会员权益`,
      logoutSuccess: "已退出登录",
      memberEntryHint: "可在设置页开启会员权益（演示入口）",
    };
  }
  return {
    insightGenerated: (label) => `${label}分析已生成`,
    weatherOff: "已关闭天气/季节场景智能提醒",
    weatherOn: "天气/季节场景智能提醒已开启",
    weatherDenied: "未获取定位权限，将继续使用通用建议",
    loginSuccess: "登录成功，账号同步入口已启用",
    upgradeSuccess: (planName) => `${planName}已开通，会员功能已生效`,
    logoutSuccess: "已退出账号",
    memberEntryHint: "可在设置页查看会员功能（演示入口）",
  };
}

function getDialogCopy() {
  if (isPetModeActive()) {
    return {
      upgradeConfirm: "升级后，小宠物就能陪你解锁更多玩法啦，确定要升级吗？",
      logoutConfirm: "确定要退出吗？本地数据不会丢失",
    };
  }
  return {
    upgradeConfirm: "确认开通会员吗？开通后将解锁完整高级功能。",
    logoutConfirm: "确认退出账号吗？本地数据不会丢失。",
  };
}

function buildLocalDailyInsightFallback(total, topCategory) {
  if (isPetModeActive()) {
    return {
      summary: `${state.settings.displayName}，今天总支出 ${formatCNY(total)}，主要花在${topCategory}。`,
      action: total > 100 ? "明天把一笔冲动小额消费换成计划内消费，会更轻松。" : "今天节奏很稳，继续保持每笔记录就很好。",
      encourage: total > 0 ? "你今天记录得很认真，继续保持就很棒。" : "今天还没消费也没关系，保持记录习惯就很好。",
    };
  }
  return {
    summary: `今日总支出 ${formatCNY(total)}，主要集中在${topCategory}。`,
    action: total > 100 ? "可关注一笔非计划支出，明天更容易保持稳定节奏。" : "当前消费节奏平稳，继续保持记录即可。",
    encourage: total > 0 ? "记录已经形成闭环，继续保持这个节奏就很好。" : "暂无消费也没关系，按日记录会让趋势更清晰。",
  };
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

function triggerPetMicroAction(action, bubbleText = "") {
  if (!state.settings.petCompanionEnabled || isPetTemporarilyHidden()) return;
  const btn = refs.petBtn;
  const face = btn?.querySelector(".pet-face");
  if (!btn || !face) return;
  btn.classList.remove("pet-action-stamp", "pet-action-nod");
  face.classList.remove("pet-action-blink");
  clearTimeout(petActionTimer);
  if (action === "stamp") {
    btn.classList.add("pet-action-stamp");
  } else if (action === "nod") {
    btn.classList.add("pet-action-nod");
  }
  if (action === "blink") {
    face.classList.add("pet-action-blink");
  }
  if (bubbleText) {
    showPetBubble(bubbleText);
  }
  petActionTimer = setTimeout(() => {
    btn.classList.remove("pet-action-stamp", "pet-action-nod");
    face.classList.remove("pet-action-blink");
  }, 900);
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

function shouldCallWeatherAIPet(trigger = "random") {
  const now = Date.now();
  const last = Number(localStorage.getItem(WEATHER_AI_PET_COOLDOWN_KEY) || "0");
  const cooldownMs = 1000 * 30;
  if (now - last < cooldownMs) return false;
  localStorage.setItem(WEATHER_AI_PET_COOLDOWN_KEY, String(now));
  return true;
}

function hasWeatherPermissionReady() {
  return Boolean(weatherGeo);
}

function isWeekend(dateText) {
  const d = new Date(dateText || Date.now());
  const day = d.getDay();
  return day === 0 || day === 6;
}

function isMonthEnd(dateText) {
  const d = new Date(dateText || Date.now());
  return d.getDate() >= MONTH_END_START_DAY;
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

function todayPaidItems() {
  const todayKey = new Date().toISOString().slice(0, 10);
  return state.items.filter((x) => x.createdAt.slice(0, 10) === todayKey && x.amount > 0);
}

function todayExpenseTotal() {
  return todayPaidItems().reduce((sum, x) => sum + x.amount, 0);
}

function commuteExpenseCountToday() {
  return todayPaidItems().filter((x) => x.category === "交通").length;
}

function hasGroceryExpenseToday() {
  return todayPaidItems().some((x) => {
    const text = `${x.title || ""} ${x.category || ""}`.toLowerCase();
    return /(超市|买菜|菜市场|日用|杂货|水果|餐饮)/.test(text);
  });
}

function isRainyWeatherCode(code) {
  if (!Number.isFinite(code)) return false;
  const rainyCodes = new Set([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]);
  return rainyCodes.has(Number(code));
}

function monthExpenseTotal() {
  const monthKey = new Date().toISOString().slice(0, 7);
  return state.items
    .filter((x) => x.createdAt.startsWith(monthKey) && x.amount > 0)
    .reduce((sum, x) => sum + x.amount, 0);
}

function hasMonthExpensePressure(recordLike) {
  if (!isMonthEnd(recordLike?.createdAt)) return false;
  return monthExpenseTotal() >= MONTH_EXPENSE_SOFT_THRESHOLD;
}

function pickSceneLocalPetMessage(recordLike, weather) {
  for (const rule of PET_SCENE_RULES) {
    if (rule.match({ recordLike, weather })) {
      return pickWeatherContextByKey(rule.key);
    }
  }
  return null;
}

function hasCoolingExpenseToday() {
  const todayItems = todayPaidItems();
  if (!todayItems.length) return false;
  return todayItems.some((item) => {
    const text = `${item.title || ""} ${item.category || ""}`.toLowerCase();
    return COOLING_EXPENSE_KEYWORDS.some((keyword) => text.includes(keyword.toLowerCase()));
  });
}

function pickWeatherContextByKey(key) {
  const block = petCopy.weatherContext[key];
  if (!block) return null;
  return Array.isArray(block) ? pickRandom(block) : block;
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

async function refreshWeatherInBackground({ refreshGeo = false } = {}) {
  if (!state.settings.weatherCompanionEnabled) return null;
  if (typeof navigator === "undefined" || !navigator.geolocation) return null;
  if (!weatherGeo || refreshGeo) {
    try {
      await new Promise((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(
          (pos) => {
            weatherGeo = { lat: pos.coords.latitude, lon: pos.coords.longitude };
            resolve(true);
          },
          () => reject(new Error("geo denied")),
          { timeout: 5000, maximumAge: 1000 * 60 * 30 }
        );
      });
    } catch {
      return null;
    }
  }
  return fetchWeatherSnapshot();
}

function stopWeatherAutoRefresh() {
  if (weatherRefreshTimer) {
    clearInterval(weatherRefreshTimer);
    weatherRefreshTimer = null;
  }
}

function startWeatherAutoRefresh() {
  stopWeatherAutoRefresh();
  if (!state.settings.weatherCompanionEnabled) return;
  refreshWeatherInBackground({ refreshGeo: true });
  weatherRefreshTimer = setInterval(() => {
    refreshWeatherInBackground({ refreshGeo: true });
  }, 1000 * 60 * 30);
}

async function buildContextualPetMessage(recordLike) {
  if (!state.settings.weatherCompanionEnabled) {
    if (isDrinkOrSnack(recordLike) && shouldNudgeWeather()) {
      return pickRandom(petCopy.weatherHint);
    }
    if (todayExpenseTotal() <= 0 && Math.random() < 0.4) {
      return pickRandom(petCopy.weatherContext.noExpenseCalm);
    }
    return pickRandom(petCopy.recordSaved);
  }
  if (!hasWeatherPermissionReady()) {
    if (shouldNudgeWeather()) {
      return "还没拿到定位权限呢，先用通用温柔提醒陪你记录～";
    }
    return pickRandom(petCopy.recordSaved);
  }
  const weather = await fetchWeatherSnapshot();
  const sceneText = pickSceneLocalPetMessage(recordLike, weather);
  if (sceneText) return sceneText;
  if (weather?.temp <= 12 && isDrinkOrSnack(recordLike)) {
    return pickWeatherContextByKey("coldDrink");
  }
  if (isWeekend(recordLike.createdAt) && /(娱乐|餐饮)/.test(recordLike.category || "")) {
    return pickWeatherContextByKey("weekendRelax");
  }
  if (isLateNight(recordLike.createdAt) && isDrinkOrSnack(recordLike)) {
    return pickWeatherContextByKey("lateNightSnack");
  }
  if (state.settings.remoteAIEnabled && Math.random() < 0.35 && shouldCallWeatherAIPet("random")) {
    const aiText = await buildWeatherSpendPetMessage("random");
    if (aiText) return aiText;
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

function dateInputValue(date) {
  return date.toISOString().slice(0, 10);
}

function buildQuickRange(kind) {
  const end = new Date();
  const start = new Date();
  if (kind === "7d") {
    start.setDate(end.getDate() - 6);
  } else if (kind === "30d") {
    start.setDate(end.getDate() - 29);
  } else if (kind === "year") {
    start.setMonth(0, 1);
  } else {
    start.setDate(1);
  }
  return { start: dateInputValue(start), end: dateInputValue(end) };
}

function getCurrentBillRangeOrDefault() {
  const start = state.billCustomRangeStart;
  const end = state.billCustomRangeEnd;
  if (start && end) return { start, end };
  return buildQuickRange("month");
}

function getBillRangeForMode(mode) {
  if (mode === "week") return buildQuickRange("7d");
  if (mode === "month") return buildQuickRange("month");
  if (mode === "year") return buildQuickRange("year");
  return getCurrentBillRangeOrDefault();
}

function openBillDateRangeModal() {
  setUIModal("billDateRange");
  billRangeDraftMode = state.period || "month";
  const range = getBillRangeForMode(billRangeDraftMode);
  refs.billDateRangeStartInput.value = range.start;
  refs.billDateRangeEndInput.value = range.end;
  renderBillDateRangeSelectionUI(billRangeDraftMode);
  refs.billDateRangeModal.classList.remove("hidden");
}

function closeBillDateRangeModal() {
  setUIModal("none");
  refs.billDateRangeModal.classList.add("hidden");
}

function renderBillDateRangeSelectionUI(mode) {
  const nextMode = mode || "month";
  refs.billPresetWeekBtn.classList.toggle("is-selected", nextMode === "week");
  refs.billPresetMonthBtn.classList.toggle("is-selected", nextMode === "month");
  refs.billPresetYearBtn.classList.toggle("is-selected", nextMode === "year");
  refs.billDateRangeModal.querySelector(".bill-date-range-modal")?.classList.toggle("custom-mode", nextMode === "custom");
}

function fillBillDateInputsByPreset(mode) {
  const kind = mode === "week" ? "7d" : mode === "year" ? "year" : "month";
  const range = buildQuickRange(kind);
  refs.billDateRangeStartInput.value = range.start;
  refs.billDateRangeEndInput.value = range.end;
}

function updateBillCustomRangeBtnText() {
  const periodLabel =
    state.period === "week"
      ? "本周"
      : state.period === "month"
        ? "本月"
        : state.period === "year"
          ? "本年"
          : "自定义日期";
  refs.billDateFilterBtn.textContent = periodLabel;
}

function formatCNY(value) {
  return value.toLocaleString("zh-CN", { style: "currency", currency: "CNY" });
}

function readableLen(text) {
  return String(text || "").replace(/\s/g, "").length;
}

function shortenText(text, maxLen) {
  const normalized = String(text || "").replace(/\s+/g, " ").trim();
  if (readableLen(normalized) <= maxLen) return normalized;
  let trimmed = normalized;
  while (trimmed && readableLen(trimmed) > maxLen) {
    trimmed = trimmed.slice(0, -1);
  }
  return trimmed.replace(/[，、。；：,.!?！]+$/, "。");
}

function normalizeAICopy(text, period) {
  const limit = AI_COPY_LIMITS[period] || AI_COPY_LIMITS.daily;
  let next = String(text || "").trim();
  if (!next) return "";
  AI_FORBIDDEN_WORDS.forEach((word) => {
    const re = new RegExp(word, "g");
    next = next.replace(re, AI_SOFT_REPLACEMENTS[word] || "温柔参考");
  });
  if (!/[。！？]$/.test(next)) next += "。";
  return shortenText(next, limit.max);
}

function buildSoftBudgetDraft() {
  const last7 = [];
  const start = new Date();
  start.setDate(start.getDate() - 6);
  start.setHours(0, 0, 0, 0);
  state.items.forEach((item) => {
    if (new Date(item.createdAt) >= start && item.amount > 0) last7.push(item);
  });
  if (!last7.length) {
    return "先随手记几笔，我们再一起整理下周生活开销参考。";
  }
  const total = last7.reduce((sum, x) => sum + x.amount, 0);
  const weeklyRef = Math.max(1, Math.round((total / 7) * 7));
  return `已按近7天节奏生成一份柔和参考：下周生活开销约 ${formatCNY(weeklyRef)}，可随心微调。`;
}

function inferEmotionTag(item) {
  const category = item?.category || "其他";
  const amount = Number(item?.amount || 0);
  if (category === "餐饮") return amount >= 40 ? "小确幸时刻" : "日常补给";
  if (category === "购物") return amount >= 100 ? "给自己加点好心情" : "生活补给";
  if (category === "娱乐") return "生活小确幸";
  if (category === "交通") return "为生活奔波的一天";
  if (category === "日用") return "把日子照顾好";
  return "认真生活记录中";
}

function topSpendCategoryWithin(days = 7) {
  const start = new Date();
  start.setDate(start.getDate() - (days - 1));
  start.setHours(0, 0, 0, 0);
  const map = {};
  state.items.forEach((item) => {
    if (new Date(item.createdAt) < start || item.amount <= 0) return;
    map[item.category] = (map[item.category] || 0) + item.amount;
  });
  return Object.entries(map).sort((a, b) => b[1] - a[1])[0]?.[0] || "餐饮";
}

function buildWeeklyRhythmText() {
  const topCategory = topSpendCategoryWithin(7);
  return `本周开销以「${topCategory}」为主，先按当前节奏温柔安排，下周再慢慢微调。`;
}

function buildWeeklyShareCardText() {
  const start = new Date();
  start.setDate(start.getDate() - 6);
  start.setHours(0, 0, 0, 0);
  const weekItems = state.items.filter((item) => new Date(item.createdAt) >= start && item.amount > 0);
  if (!weekItems.length) return "周度分享卡：这周还在轻松起步，继续记录就会慢慢看到你的生活节奏。";
  const weekTotal = weekItems.reduce((sum, item) => sum + item.amount, 0);
  const topCategory = topSpendCategoryWithin(7);
  return `周度分享卡：本周记录 ${weekItems.length} 笔，生活开销约 ${formatCNY(weekTotal)}，主要在「${topCategory}」。`;
}

function buildWeeklyShareMeta() {
  const start = new Date();
  start.setDate(start.getDate() - 6);
  start.setHours(0, 0, 0, 0);
  const weekItems = state.items.filter((item) => new Date(item.createdAt) >= start && item.amount > 0);
  const weekTotal = weekItems.reduce((sum, item) => sum + item.amount, 0);
  const dailyMap = {};
  weekItems.forEach((item) => {
    const key = new Date(item.createdAt).toISOString().slice(0, 10);
    dailyMap[key] = (dailyMap[key] || 0) + item.amount;
  });
  const dailyTrend = Array.from({ length: 7 }, (_, idx) => {
    const d = new Date(start);
    d.setDate(start.getDate() + idx);
    const key = d.toISOString().slice(0, 10);
    return {
      key,
      label: `${d.getMonth() + 1}/${d.getDate()}`,
      amount: Number(dailyMap[key] || 0),
    };
  });
  const categoryMap = {};
  weekItems.forEach((item) => {
    categoryMap[item.category] = (categoryMap[item.category] || 0) + item.amount;
  });
  const topCategoryAmount = Number(categoryMap[topSpendCategoryWithin(7)] || 0);
  return {
    count: weekItems.length,
    total: formatCNY(weekTotal),
    topCategory: topSpendCategoryWithin(7),
    topCategoryAmount: formatCNY(topCategoryAmount),
    topCategoryRatio: weekTotal > 0 ? topCategoryAmount / weekTotal : 0,
    dailyTrend,
    period: `${start.toISOString().slice(0, 10)} ~ ${new Date().toISOString().slice(0, 10)}`,
  };
}

function drawRoundRect(ctx, x, y, w, h, r) {
  const radius = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.arcTo(x + w, y, x + w, y + h, radius);
  ctx.arcTo(x + w, y + h, x, y + h, radius);
  ctx.arcTo(x, y + h, x, y, radius);
  ctx.arcTo(x, y, x + w, y, radius);
  ctx.closePath();
}

async function downloadWeeklyShareCardImage() {
  const meta = buildWeeklyShareMeta();
  if (!meta.count) {
    showToast("近7天还没有记录，先记几笔再生成分享卡。");
    return false;
  }
  if (typeof document === "undefined" || typeof HTMLCanvasElement === "undefined") {
    showToast("当前环境不支持图片生成。");
    return false;
  }
  const isPetTheme = state.settings.petCompanionEnabled !== false;
  const theme = isPetTheme
    ? {
        bgStart: "#fff3e8",
        bgEnd: "#ffe9f2",
        panelShadow: "rgba(197, 132, 88, 0.18)",
        panelBg: "rgba(255,255,255,0.94)",
        panelBorder: "#efd7c7",
        accent: "#d48754",
        accentSoft: "#e4a57a",
        titleSub: "#b79a86",
        textMain: "#4a3f37",
        textMuted: "#957f70",
        trendPanelBg: "rgba(212, 135, 84, 0.11)",
        trendPanelBorder: "rgba(212, 135, 84, 0.28)",
        ringPanelBg: "rgba(212, 135, 84, 0.10)",
        ringPanelBorder: "rgba(212, 135, 84, 0.24)",
        trendLabel: "#8e7a6d",
        trendPeakShadow: "rgba(212, 135, 84, 0.35)",
        trendPeakBar: "#d48754",
        trendBar: "#e4a57a",
        trendBarMuted: "rgba(228, 165, 122, 0.28)",
        ringTrack: "rgba(228,165,122,0.22)",
        ringArc: "#d48754",
        footer: "#887566",
        footerSub: "#b19c8e",
      }
    : {
        bgStart: "#f3f6fb",
        bgEnd: "#edf1f7",
        panelShadow: "rgba(94, 111, 138, 0.16)",
        panelBg: "rgba(255,255,255,0.95)",
        panelBorder: "#d8deea",
        accent: "#5e708a",
        accentSoft: "#7788a2",
        titleSub: "#8c96a8",
        textMain: "#2f3947",
        textMuted: "#6f7a8d",
        trendPanelBg: "rgba(94, 112, 138, 0.10)",
        trendPanelBorder: "rgba(94, 112, 138, 0.24)",
        ringPanelBg: "rgba(94, 112, 138, 0.10)",
        ringPanelBorder: "rgba(94, 112, 138, 0.22)",
        trendLabel: "#768196",
        trendPeakShadow: "rgba(94, 112, 138, 0.30)",
        trendPeakBar: "#5e708a",
        trendBar: "#7788a2",
        trendBarMuted: "rgba(119, 136, 162, 0.24)",
        ringTrack: "rgba(119,136,162,0.22)",
        ringArc: "#5e708a",
        footer: "#6b7688",
        footerSub: "#8f99ab",
      };
  const nickname = (state.settings.displayName || "叙帐用户").trim();
  const canvas = document.createElement("canvas");
  canvas.width = 1080;
  canvas.height = 1350;
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    showToast("图片引擎初始化失败。");
    return false;
  }

  const bgGradient = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
  bgGradient.addColorStop(0, theme.bgStart);
  bgGradient.addColorStop(1, theme.bgEnd);
  ctx.fillStyle = bgGradient;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  ctx.save();
  ctx.shadowColor = theme.panelShadow;
  ctx.shadowBlur = 30;
  ctx.shadowOffsetY = 8;
  drawRoundRect(ctx, 80, 120, 920, 1100, 48);
  ctx.fillStyle = theme.panelBg;
  ctx.fill();
  ctx.restore();

  drawRoundRect(ctx, 80, 120, 920, 1100, 48);
  ctx.strokeStyle = theme.panelBorder;
  ctx.lineWidth = 2;
  ctx.stroke();

  ctx.fillStyle = theme.accent;
  ctx.font = "700 56px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
  ctx.fillText("叙帐 · 周度分享卡", 140, 230);
  ctx.font = "400 30px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
  ctx.fillStyle = theme.titleSub;
  ctx.fillText(meta.period, 140, 290);
  if (isPetTheme) {
    ctx.save();
    ctx.strokeStyle = "rgba(212, 135, 84, 0.75)";
    ctx.lineWidth = 3;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.beginPath();
    ctx.moveTo(902, 176);
    ctx.lineTo(920, 150);
    ctx.lineTo(938, 176);
    ctx.arc(920, 196, 20, Math.PI * 1.08, Math.PI * -0.08, true);
    ctx.moveTo(948, 176);
    ctx.lineTo(966, 150);
    ctx.lineTo(984, 176);
    ctx.arc(966, 196, 20, Math.PI * 1.08, Math.PI * -0.08, true);
    ctx.stroke();
    ctx.restore();
  } else {
    ctx.save();
    ctx.strokeStyle = "rgba(94, 112, 138, 0.72)";
    ctx.lineWidth = 3;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(900, 162);
    ctx.lineTo(982, 162);
    ctx.moveTo(914, 184);
    ctx.lineTo(964, 184);
    ctx.moveTo(930, 206);
    ctx.lineTo(982, 206);
    ctx.stroke();
    ctx.restore();
  }

  ctx.fillStyle = theme.textMain;
  ctx.font = "500 36px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
  ctx.fillText(`你好，${nickname}`, 140, 390);
  ctx.font = "600 42px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
  ctx.fillText("这一周你记录得很认真", 140, 460);

  const lines = [`记录 ${meta.count} 笔`, `总开销 ${meta.total}`, `常花类目 ${meta.topCategory}`];
  ctx.fillStyle = theme.accent;
  ctx.font = "700 62px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
  lines.forEach((line, idx) => {
    ctx.fillText(line, 140, 580 + idx * 100);
  });

  const trendX = 128;
  const trendY = 812;
  const trendW = 542;
  const trendH = 194;
  drawRoundRect(ctx, trendX, trendY, trendW, trendH, 24);
  ctx.fillStyle = theme.trendPanelBg;
  ctx.fill();
  drawRoundRect(ctx, trendX, trendY, trendW, trendH, 24);
  ctx.strokeStyle = theme.trendPanelBorder;
  ctx.lineWidth = 1.5;
  ctx.stroke();
  ctx.fillStyle = theme.trendLabel;
  ctx.font = "500 26px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
  ctx.fillText("近7天小趋势", trendX + 20, trendY + 38);
  const maxTrend = Math.max(...meta.dailyTrend.map((x) => x.amount), 1);
  const barBase = trendY + trendH - 34;
  const barGap = 14;
  const barW = 50;
  const peakAmount = Math.max(...meta.dailyTrend.map((x) => x.amount));
  meta.dailyTrend.forEach((entry, idx) => {
    const x = trendX + 22 + idx * (barW + barGap);
    const h = Math.max(6, (entry.amount / maxTrend) * 98);
    const y = barBase - h;
    drawRoundRect(ctx, x, y, barW, h, 12);
    const isPeak = entry.amount > 0 && entry.amount === peakAmount;
    if (isPeak) {
      ctx.save();
      ctx.shadowColor = theme.trendPeakShadow;
      ctx.shadowBlur = 10;
      ctx.shadowOffsetY = 2;
      ctx.fillStyle = theme.trendPeakBar;
      ctx.fill();
      ctx.restore();
      drawRoundRect(ctx, x + 8, y + 6, barW - 16, 8, 4);
      ctx.fillStyle = "rgba(255,255,255,0.4)";
      ctx.fill();
    } else {
      ctx.fillStyle = entry.amount > 0 ? theme.trendBar : theme.trendBarMuted;
      ctx.fill();
    }
    ctx.fillStyle = theme.titleSub;
    ctx.font = "400 15px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
    const labelW = ctx.measureText(entry.label).width;
    ctx.fillText(entry.label, x + barW / 2 - labelW / 2, barBase + 24);
  });

  const ringCx = 820;
  const ringCy = 914;
  const ringR = 85;
  drawRoundRect(ctx, 700, 804, 240, 262, 24);
  ctx.fillStyle = theme.ringPanelBg;
  ctx.fill();
  drawRoundRect(ctx, 700, 804, 240, 262, 24);
  ctx.strokeStyle = theme.ringPanelBorder;
  ctx.lineWidth = 1.5;
  ctx.stroke();
  const ratio = Math.max(0, Math.min(1, meta.topCategoryRatio || 0));
  ctx.lineWidth = 20;
  ctx.strokeStyle = theme.ringTrack;
  ctx.beginPath();
  ctx.arc(ringCx, ringCy, ringR, 0, Math.PI * 2);
  ctx.stroke();
  ctx.strokeStyle = theme.ringArc;
  ctx.beginPath();
  ctx.arc(ringCx, ringCy, ringR, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * ratio);
  ctx.stroke();
  ctx.fillStyle = theme.accent;
  ctx.font = "700 34px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
  const ratioText = `${Math.round(ratio * 100)}%`;
  const ratioTextW = ctx.measureText(ratioText).width;
  ctx.fillText(ratioText, ringCx - ratioTextW / 2, ringCy + 10);
  ctx.fillStyle = theme.textMuted;
  ctx.font = "500 21px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
  const topTitle = "TOP类目占比";
  const topTitleW = ctx.measureText(topTitle).width;
  ctx.fillText(topTitle, ringCx - topTitleW / 2, ringCy - 112);
  const topLabel = `${meta.topCategory} · ${meta.topCategoryAmount}`;
  const topLabelW = ctx.measureText(topLabel).width;
  ctx.fillText(topLabel, ringCx - topLabelW / 2, ringCy + 136);

  ctx.fillStyle = theme.footer;
  ctx.font = "400 32px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
  ctx.fillText("温柔回看，不必苛责，按自己的节奏慢慢生活。", 140, 1110);
  ctx.fillStyle = theme.footerSub;
  ctx.font = "400 27px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
  ctx.fillText("来自 叙帐 · 小 AI 说", 140, 1172);

  let blob = null;
  if (canvas.toBlob) {
    blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/png", 1));
  }
  if (!blob) {
    const dataUrl = canvas.toDataURL("image/png");
    const fallbackLink = document.createElement("a");
    fallbackLink.href = dataUrl;
    fallbackLink.download = `周度分享卡-${new Date().toISOString().slice(0, 10)}.png`;
    document.body.appendChild(fallbackLink);
    fallbackLink.click();
    document.body.removeChild(fallbackLink);
    return true;
  }
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `周度分享卡-${new Date().toISOString().slice(0, 10)}.png`;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  setTimeout(() => URL.revokeObjectURL(url), 3000);
  return true;
}

function buildMonthlySoftPlanText() {
  const monthKey = thisMonthKey();
  const monthItems = state.items.filter((x) => x.createdAt.startsWith(monthKey) && x.amount > 0);
  if (!monthItems.length) return "先继续轻松记录几笔，下月参考会更贴近你的生活节奏。";
  const total = monthItems.reduce((sum, x) => sum + x.amount, 0);
  const nextRef = Math.max(1, Math.round(total * 0.95));
  return `下月生活开销温柔参考：约 ${formatCNY(nextRef)}，按你自己的节奏随心调整。`;
}

function getConfiguredAIModel() {
  try {
    const runtimeModel = typeof localStorage !== "undefined" ? (localStorage.getItem(AI_MODEL_STORAGE_KEY) || "").trim() : "";
    return runtimeModel || DEFAULT_AI_MODEL;
  } catch {
    return DEFAULT_AI_MODEL;
  }
}

function getConfiguredAITimeoutMs(period = "daily") {
  try {
    const raw = typeof localStorage !== "undefined" ? localStorage.getItem(AI_TIMEOUT_MS_STORAGE_KEY) : "";
    const parsed = Number(raw);
    if (Number.isFinite(parsed) && parsed >= 3000) {
      return parsed;
    }
    return PERIOD_TIMEOUT_MS[period] || DEFAULT_AI_TIMEOUT_MS;
  } catch {
    return PERIOD_TIMEOUT_MS[period] || DEFAULT_AI_TIMEOUT_MS;
  }
}

function buildAIHeaders() {
  const headers = { "Content-Type": "application/json" };
  if (typeof localStorage !== "undefined") {
    const proxyToken = (localStorage.getItem(AI_PROXY_TOKEN_STORAGE_KEY) || "").trim();
    const userToken = (localStorage.getItem(AI_USER_TOKEN_STORAGE_KEY) || "").trim();
    if (proxyToken) headers["x-proxy-token"] = proxyToken;
    if (userToken) headers.Authorization = `Bearer ${userToken}`;
  }
  return headers;
}

async function buildWeatherSpendPetMessage(trigger = "click") {
  if (!hasWeatherPermissionReady()) return pickRandom(petCopy.weatherAiFallback);
  const todayKey = new Date().toISOString().slice(0, 10);
  const todayItems = state.items.filter((x) => x.createdAt.slice(0, 10) === todayKey && x.amount > 0);
  if (!todayItems.length) return pickRandom(petCopy.weatherAiFallback);
  const total = todayItems.reduce((sum, x) => sum + x.amount, 0);
  const topCategory = topCategoryFor(todayItems) || "暂无";
  const weather = state.settings.weatherCompanionEnabled ? await fetchWeatherSnapshot() : null;
  const weatherFacts = {
    enabled: Boolean(state.settings.weatherCompanionEnabled),
    hasLocation: Boolean(weatherGeo),
    available: Boolean(weather),
    tempC: Number.isFinite(weather?.temp) ? weather.temp : null,
    weatherCode: Number.isFinite(weather?.weatherCode) ? weather.weatherCode : null,
  };
  const userPrompt = `请你用小宠物第一人称口吻，结合今日消费和天气给一句温柔建议。只输出JSON：{"summary":"...","action":"...","encourage":"..."}。summary控制在28-48字，语气要像宠物陪伴，不评判、不说教。数据：触发方式=${trigger}，今日总支出=${formatCNY(total)}，记录笔数=${todayItems.length}，主要分类=${topCategory}，天气信息=${JSON.stringify(weatherFacts)}。`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), getConfiguredAITimeoutMs("daily"));
  try {
    const response = await fetch(INSIGHT_AI_ENDPOINT, {
      method: "POST",
      headers: buildAIHeaders(),
      body: JSON.stringify({
        model: getConfiguredAIModel(),
        feature: "daily",
        messages: [
          { role: "system", content: "你是会陪伴用户记账的小宠物，说话温柔、治愈、生活化。输出JSON字段summary/action/encourage。" },
          { role: "user", content: userPrompt },
        ],
        temperature: 0.75,
      }),
      signal: controller.signal,
    });
    clearTimeout(timer);
    if (!response.ok) return pickRandom(petCopy.weatherAiFallback);
    const data = await response.json();
    const payload = normalizeInsightResponse(data);
    if (!payload?.summary) return pickRandom(petCopy.weatherAiFallback);
    return normalizeAICopy(payload.summary, "daily");
  } catch {
    clearTimeout(timer);
    return pickRandom(petCopy.weatherAiFallback);
  }
}

function topCategoryStats(items) {
  const bucket = {};
  items.forEach((item) => {
    bucket[item.category] = (bucket[item.category] || 0) + Math.max(item.amount, 0);
  });
  const sorted = Object.entries(bucket).sort((a, b) => b[1] - a[1]);
  return sorted.slice(0, 3).map(([category, amount]) => ({
    category,
    amount,
  }));
}

function buildInsightFacts(items, label) {
  const positiveItems = items.filter((x) => x.amount > 0);
  const total = positiveItems.reduce((sum, x) => sum + x.amount, 0);
  const stats = topCategoryStats(positiveItems);
  const top = stats[0];
  const ratio = top && total > 0 ? Math.round((top.amount / total) * 100) : 0;
  return {
    label,
    total: formatCNY(total),
    count: positiveItems.length,
    topCategory: top?.category || "暂无",
    topRatio: ratio,
    categories: stats.map((x) => `${x.category}${formatCNY(x.amount)}`).join("、") || "暂无",
  };
}

function buildPeriodPrompt(period, facts) {
  if (period === "monthly") {
    return `结合全月账单，写一段120-150字月度温柔月报。只输出JSON：{"summary":"...","action":"...","encourage":"..."}。其中summary必须120-150字，内容需包含月度消费趋势与生活节奏；action给出客观结构观察（如饮食占比、通勤稳定、零散消费），encourage给出温柔陪伴句。数据：周期=${facts.label}，总支出=${facts.total}，记录笔数=${facts.count}，TOP分类=${facts.topCategory}（占比约${facts.topRatio}%），分类明细=${facts.categories}。`;
  }
  if (period === "weekly") {
    return `结合本周账单，写一段70-90字温柔周复盘。只输出JSON：{"summary":"...","action":"...","encourage":"..."}。其中summary必须70-90字，强调消费结构与习惯观察；action给一句温和、有用的客观提示；encourage给一句治愈鼓励。数据：周期=${facts.label}，总支出=${facts.total}，记录笔数=${facts.count}，TOP分类=${facts.topCategory}（占比约${facts.topRatio}%），分类明细=${facts.categories}。`;
  }
  return `结合今日账单，写一段35-45字温柔小结。只输出JSON：{"summary":"...","action":"...","encourage":"..."}。其中summary必须35-45字且轻量好读；action与encourage各1句，延续温柔、不评判语气。数据：周期=${facts.label}，总支出=${facts.total}，记录笔数=${facts.count}，TOP分类=${facts.topCategory}（占比约${facts.topRatio}%），分类明细=${facts.categories}。`;
}

function normalizeInsightResponse(data) {
  if (!data || typeof data !== "object") return null;
  const summary = typeof data.summary === "string" ? data.summary.trim() : "";
  const action = typeof data.action === "string" ? data.action.trim() : "";
  const encourage = typeof data.encourage === "string" ? data.encourage.trim() : "";
  if (!summary) return null;
  return { summary, action, encourage };
}

async function requestAIInsight(period, items, label, feature = period) {
  if (!state.settings.remoteAIEnabled) return { ok: false, reason: "remote-off" };
  const facts = buildInsightFacts(items, label);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), getConfiguredAITimeoutMs(period));
  try {
    const headers = buildAIHeaders();
    const response = await fetch(INSIGHT_AI_ENDPOINT, {
      method: "POST",
      headers,
      body: JSON.stringify({
        model: getConfiguredAIModel(),
        feature,
        messages: [
          { role: "system", content: AI_GLOBAL_STYLE_PROMPT },
          { role: "user", content: buildPeriodPrompt(period, facts) },
        ],
        temperature: 0.7,
      }),
      signal: controller.signal,
    });
    clearTimeout(timer);
    if (!response.ok) return { ok: false, reason: `http-${response.status}` };
    const data = await response.json();
    const payload = normalizeInsightResponse(data);
    if (!payload) return { ok: false, reason: "invalid-payload" };
    return {
      ok: true,
      payload: {
        summary: normalizeAICopy(payload.summary, period),
        action: normalizeAICopy(payload.action, "daily"),
        encourage: normalizeAICopy(payload.encourage, "daily"),
      },
    };
  } catch (_error) {
    clearTimeout(timer);
    return { ok: false, reason: "network" };
  }
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

function applyAmountQuickAction(action) {
  if (action === "dot00") {
    if (!hasAmountStreamValue()) {
      amountStream = { intPart: "0", decPart: "00", hasDot: true };
    } else {
      amountStream.hasDot = true;
      amountStream.decPart = "00";
    }
    syncAmountUIAfterInput({ shouldRecommend: false });
    return;
  }
  const deltaMap = {
    plus10: 10,
    plus50: 50,
    plus100: 100,
  };
  const delta = deltaMap[action];
  if (!delta) return;
  const nextValue = Math.max(0, getAmountValue() + delta);
  amountStream = parseAmountTextToStream(nextValue.toFixed(2));
  syncAmountUIAfterInput();
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
    refs.titleInput.placeholder = "这一笔像什么？不写也能保存";
    return;
  }
  const meta = getCategoryMeta(selectedCategory || localRecommendedCategory());
  refs.titleInput.placeholder = `已归类到「${meta.label}」，可补充一句生活细节`;
}

// Web-only prototype states. iOS UI-P1 should use F1.3/B2.13 resolver outputs.
const prefillDemoPresets = {
  brand: {
    headline: "瑞幸咖啡",
    emotion: "早班路上，顺手续一口",
    actionText: "换一句说法",
    actionClass: "link-btn",
  },
  habit: {
    headline: "地铁通勤",
    emotion: "日常出行",
    actionText: "✨ 换一句",
    actionClass: "scene-quick-btn",
  },
  generic: {
    headline: "吃饭的一小笔",
    emotion: "日常一口",
    actionText: "✨ 帮我写一句",
    actionClass: "scene-primary-btn",
  },
};

function compactRecordTime() {
  const raw = refs.recordDateInput.value;
  if (!raw) return new Date().toLocaleDateString("zh-CN", { month: "numeric", day: "numeric" });
  const date = new Date(`${raw}T00:00:00`);
  if (Number.isNaN(date.getTime())) return raw;
  return date.toLocaleDateString("zh-CN", { month: "numeric", day: "numeric" });
}

function updateLifeEntryPreview() {
  const amountReady = isAmountReady();
  refs.lifeEntryPreview?.classList.toggle("hidden", !amountReady);
  refs.recordPrimaryActions?.classList.toggle("hidden", !amountReady && !editingRecordId);
  refs.recordDetailsFold?.classList.toggle("hidden", !amountReady && !editingRecordId);
  refs.prefillDemoBar?.classList.toggle("hidden", !amountReady && !editingRecordId);
  if (!amountReady && !editingRecordId) return;

  const preset = prefillDemoPresets[prefillDemoMode] || prefillDemoPresets.generic;
  const amount = getAmountValue();
  const meta = getCategoryMeta(selectedCategory || localRecommendedCategory());
  const userTitle = refs.titleInput.value.trim();
  const headline = userTitle || preset.headline;
  const emotion = preset.emotion;
  refs.lifeEntryHeadline.textContent = headline || "这一笔还没长出说法";
  refs.lifeEntryAmount.textContent = Number.isNaN(amount) ? "¥0.00" : formatCNY(amount);
  refs.lifeEntryEmotion.textContent = emotion;
  refs.lifeEntryEmotion.classList.toggle("hidden", !emotion);
  refs.lifeEntryMeta.textContent = `${meta.label} · ${compactRecordTime()}`;

  refs.lifeEntryQuickActions.innerHTML = "";
  const quickBtn = document.createElement("button");
  quickBtn.type = "button";
  quickBtn.className = preset.actionClass;
  quickBtn.textContent = preset.actionText;
  quickBtn.addEventListener("pointerdown", (event) => event.preventDefault());
  quickBtn.addEventListener("click", () => {
    if (!state.settings.isMember && prefillDemoMode === "generic") {
      openAccountOverlay();
      return;
    }
    const packId = guessMemberScenePackId();
    applyMemberScenePack(packId, { keepSelectedCategory: true });
  });
  refs.lifeEntryQuickActions.appendChild(quickBtn);

  const detailBtn = document.createElement("button");
  detailBtn.type = "button";
  detailBtn.className = "link-btn";
  detailBtn.textContent = "补充细节";
  detailBtn.addEventListener("click", () => toggleRecordDetails(true));
  refs.lifeEntryQuickActions.appendChild(detailBtn);
}

function toggleRecordDetails(force) {
  recordDetailsExpanded = typeof force === "boolean" ? force : !recordDetailsExpanded;
  refs.recordDetailsBody?.classList.toggle("hidden", !recordDetailsExpanded);
  if (refs.recordDetailsToggleHint) {
    refs.recordDetailsToggleHint.textContent = recordDetailsExpanded ? "收起" : "展开";
  }
}

function updateCategoryUI() {
  if (!selectedCategory) {
    renderCategoryOptions();
    updateNotePlaceholder();
    renderMemberScenePacks();
    updateLifeEntryPreview();
    return;
  }
  renderCategoryOptions();
  updateNotePlaceholder();
  renderMemberScenePacks();
  updateLifeEntryPreview();
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
        model: getConfiguredAIModel(),
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
  updateLifeEntryPreview();
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
    chip.addEventListener("pointerdown", (event) => {
      // Keep amount input focus so blur->render won't swallow first tap.
      event.preventDefault();
    });
    chip.addEventListener("click", () => {
      refs.titleInput.value = text;
      refs.noteSuggestions.classList.add("hidden");
      refs.noteSuggestions.innerHTML = "";
      updateLifeEntryPreview();
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
  return "小窝";
}

function personalizePetText(text) {
  if (!text) return "";
  return String(text).replace(/\{petName\}/g, resolvePetNameForNote());
}

function pickHistoryKeyword(category) {
  const cutoff = Date.now() - 90 * 24 * 60 * 60 * 1000;
  const keywords = state.items
    .filter((item) => item.category === category)
    .filter((item) => new Date(item.createdAt).getTime() >= cutoff)
    .map((item) => (item.title || "").trim())
    .filter((text) => text && !/消费$/.test(text) && text.length >= 2 && text.length <= 8);
  if (!keywords.length) return "";
  const counts = new Map();
  keywords.forEach((text) => counts.set(text, (counts.get(text) || 0) + 1));
  return [...counts.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))[0]?.[0] || "";
}

function enrichNoteWithHistory(note, category, seed = "") {
  const keyword = pickHistoryKeyword(category);
  if (!keyword) return note;
  if (note.includes(keyword)) return note;
  if (stableIndex(`${seed}|historyChance`, 100) >= 45) return note;
  return `${note}，顺带记下「${keyword}」`;
}

function localDayKey(date = new Date()) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function stableHash(seed) {
  let hash = 2166136261;
  for (let i = 0; i < seed.length; i += 1) {
    hash ^= seed.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function stableIndex(seed, count) {
  if (!count) return 0;
  return stableHash(seed) % count;
}

function scenePackTierIndex(pack, amount) {
  const index = pack.rules.findIndex((rule) => amount <= rule.max);
  return index >= 0 ? index : Math.max(0, pack.rules.length - 1);
}

function stableScenePackNote(pack, amount, categoryContext) {
  const tierIndex = scenePackTierIndex(pack, amount);
  const matchedRule = pack.rules[tierIndex] || pack.rules[pack.rules.length - 1];
  const notes = matchedRule?.notes || ["今天记一笔日常花费"];
  const seed = `${localDayKey()}|${pack.id}|${tierIndex}|${categoryContext || pack.category}`;
  return {
    seed,
    note: notes[stableIndex(seed, notes.length)] || notes[0],
  };
}

function applyMemberScenePack(packId, { keepSelectedCategory = false } = {}) {
  const pack = memberScenePacks.find((x) => x.id === packId);
  if (!pack) return;
  const amount = getAmountValue();
  const petName = resolvePetNameForNote();
  const effectiveCategory = keepSelectedCategory ? (selectedCategory || pack.category) : pack.category;
  const picked = stableScenePackNote(pack, amount, effectiveCategory);
  let phrase = picked.note;
  phrase = phrase.replace(/\{petName\}/g, petName);
  phrase = enrichNoteWithHistory(phrase, effectiveCategory, picked.seed);
  if (!keepSelectedCategory) {
    selectCategory(pack.category);
  }
  refs.titleInput.value = phrase;
  refs.noteSuggestions.classList.add("hidden");
  refs.noteSuggestions.innerHTML = "";
  scenePackExpanded = false;
  renderRecord();
  updateLifeEntryPreview();
  showToast(`已生成：${pack.label}`);
}

function guessMemberScenePackId() {
  const amount = getAmountValue();
  const categoryToPackId = {
    餐饮: "food",
    交通: "commute",
    日用: "pet",
    购物: "travel",
    娱乐: "travel",
    其他: "travel",
  };
  const byCategory = categoryToPackId[selectedCategory || ""] || "";
  if (byCategory && memberScenePacks.some((pack) => pack.id === byCategory)) return byCategory;
  if (amount <= 15) return "commute";
  if (amount <= 45) return "food";
  if (amount <= 120) return "pet";
  return "travel";
}

function renderMemberScenePacks() {
  const isManualMode = state.recordMode === "manual";
  const isEditing = Boolean(editingRecordId);
  const amountReady = isAmountReady();
  const isMember = Boolean(state.settings.isMember);
  const shouldShow = isManualMode && !isEditing && amountReady && isMember;
  refs.memberScenePackBlock.classList.toggle("hidden", !shouldShow);
  if (!shouldShow) {
    scenePackExpanded = false;
    return;
  }

  refs.memberScenePackEntryBtn.classList.add("hidden");
  refs.memberScenePackHint.textContent = scenePackExpanded
    ? "可选场景：点一个就会自动生成备注。"
    : "可选项：先点保存也没问题；需要时一键生成备注。";
  refs.memberScenePackList.innerHTML = "";
  const quickPackId = guessMemberScenePackId();
  const quickPack = memberScenePacks.find((pack) => pack.id === quickPackId) || memberScenePacks[0];
  if (quickPack) {
    const quickBtn = document.createElement("button");
    quickBtn.type = "button";
    quickBtn.className = "scene-pack-chip scene-pack-primary";
    quickBtn.innerHTML = "✨ 一键生成备注<small>按当前金额与已选分类生成，不改你的分类</small>";
    quickBtn.addEventListener("pointerdown", (event) => {
      event.preventDefault();
    });
    quickBtn.addEventListener("click", () => applyMemberScenePack(quickPack.id, { keepSelectedCategory: true }));
    refs.memberScenePackList.appendChild(quickBtn);
  }

  const toggleBtn = document.createElement("button");
  toggleBtn.type = "button";
  toggleBtn.className = "scene-pack-chip scene-pack-toggle";
  toggleBtn.innerHTML = scenePackExpanded
    ? "收起更多场景<small>回到简洁输入模式</small>"
    : "展开更多场景<small>按场景手动选择生成备注</small>";
  toggleBtn.addEventListener("pointerdown", (event) => {
    event.preventDefault();
  });
  toggleBtn.addEventListener("click", () => {
    scenePackExpanded = !scenePackExpanded;
    renderMemberScenePacks();
  });
  refs.memberScenePackList.appendChild(toggleBtn);

  if (!scenePackExpanded) return;

  memberScenePacks.forEach((pack) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "scene-pack-chip";
    const preview = pack.desc.replace(/\{petName\}/g, resolvePetNameForNote());
    btn.innerHTML = `${pack.emoji} ${pack.label}<small>${preview}</small>`;
    btn.addEventListener("pointerdown", (event) => {
      // Keep amount input focus so blur->render won't swallow first tap.
      event.preventDefault();
    });
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
    emotionTag: inferEmotionTag({ category: finalCategory, amount: Number(amount) }),
  });
  persist();
  render();
  triggerHaptic();
  trackAnalytics("record_saved", {
    category: finalCategory,
    source: source || "manual",
    amount: Number(amount),
  });
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
  setUIModal("ocrConfirm");
  ocrDraftRecords = records.map((x) => ({ ...x, selected: true }));
  refs.ocrStatsCount.textContent = String(ocrDraftRecords.length);
  const total = ocrDraftRecords.reduce((sum, x) => sum + x.amount, 0);
  refs.ocrStatsAmount.textContent = formatCNY(total);
  renderOCRConfirmList(ocrDraftRecords);
  updateOCRSelectionState();
  refs.ocrConfirmOverlay.classList.remove("hidden");
}

function closeOCRConfirm() {
  setUIModal("none");
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
  setUIModal("ocrCategory");
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
  setUIModal("none");
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
  setUIModal("monthlyTrial");
  refs.monthlyTrialModalTitle.textContent = title;
  refs.monthlyTrialModalBody.textContent = body;
  refs.monthlyTrialModal.classList.remove("hidden");
}

function getMemberCtaCopy(context = "default") {
  if (context === "playback_complete") {
    return {
      intro: "把这周的生活轨迹长期留住，回看会更温柔。",
      quickAction: "保留这周生活轨迹",
      nudge: "想把这些生活切片长期留住？开通会员可自动云端留存。",
    };
  }
  if (context === "share_success") {
    return {
      intro: "这张分享卡很温柔，继续留存每周生活卡会更有连续感。",
      quickAction: "持续留存每周生活卡",
      nudge: "分享完成啦，开通会员可持续留存每周生活卡。",
    };
  }
  if (context === "ai_monthly") {
    return {
      intro: "这次复盘只是开始，会员可解锁无限次生活复盘。",
      quickAction: "解锁无限次生活复盘",
      nudge: "想继续回看更多生活节奏？会员可解锁无限次复盘。",
    };
  }
  return {
    intro: "让记账更轻松、更省心。",
    quickAction: "立即开通年度会员（推荐）",
    nudge: "开通会员可持续留存生活记录，随时温柔回看。",
  };
}

function openMemberOffer(context = "default") {
  memberCtaContext = context || "default";
  memberPlansExpanded = false;
  setUIModal("account");
  accountOverlayView = "member";
  refs.accountOverlay.classList.remove("hidden");
  renderAccountOverlay();
}

function showMemberNudge(context = "default") {
  if (!refs.memberNudgeBar || !refs.memberNudgeText) return;
  if (!canShowMemberNudge(context)) return;
  markMemberNudgeShown(context);
  memberNudgeLastAt = Date.now();
  memberCtaContext = context || "default";
  const copy = getMemberCtaCopy(context);
  refs.memberNudgeText.textContent = copy.nudge;
  refs.memberNudgeBar.classList.remove("hidden");
  trackAnalytics("member_cta_exposed", { source: memberCtaContext, channel: "nudge_bar" });
}

function hideMemberNudge() {
  refs.memberNudgeBar?.classList.add("hidden");
}

function openAccountOverlay() {
  setUIModal("account");
  accountOverlayView = state.settings.isLoggedIn ? "center" : "login";
  refs.accountOverlay.classList.remove("hidden");
  renderAccountOverlay();
}

function closeAccountOverlay() {
  setUIModal("none");
  refs.accountOverlay.classList.add("hidden");
  memberOverlayExposureMark = "";
}

function renderAccountCenterBenefits() {
  const titleEl = refs.accountCenterBenefitsTitle;
  const leadEl = refs.accountCenterBenefitsLead;
  const listEl = refs.accountCenterBenefitsList;
  if (!titleEl || !leadEl || !listEl) return;

  const isMember = Boolean(state.settings.isMember);
  const petOn = Boolean(state.settings.petCompanionEnabled);

  if (isMember && petOn) {
    const petName = resolvePetNameForNote();
    titleEl.textContent = `✨ ${petName}在这儿陪着你呀～`;
    leadEl.textContent = "你的会员权益都已解锁：";
    leadEl.classList.remove("hidden");
    listEl.innerHTML = MEMBER_BENEFITS.slice(0, 3).map((item) => `<li>${item.title.replace(/^[^\s]+ /, "")}</li>`).join("");
    return;
  }

  if (isMember && !petOn) {
    titleEl.textContent = "✨ 你的会员权益已生效";
    leadEl.textContent = "感谢你的支持，以下权益你都可以随时使用：";
    leadEl.classList.remove("hidden");
    listEl.innerHTML = MEMBER_BENEFITS.slice(0, 3).map((item) => `<li>${item.title.replace(/^[^\s]+ /, "")}</li>`).join("");
    return;
  }

  titleEl.textContent = petOn ? "✨ 升级会员，解锁更多温柔陪伴" : "✨ 升级会员，解锁更多实用权益";
  leadEl.textContent = "";
  leadEl.classList.add("hidden");
  listEl.innerHTML = MEMBER_BENEFITS.slice(0, 3).map((item) => `<li>${item.title.replace(/^[^\s]+ /, "")}</li>`).join("");
}

function renderMemberUpgradeBenefits() {
  const titleEl = refs.accountMemberHeroTitle;
  const introEl = refs.accountMemberHeroIntro;
  const listEl = refs.accountMemberBenefitsList;
  if (!titleEl || !introEl || !listEl) return;
  const petOn = Boolean(state.settings.petCompanionEnabled);
  const ctaCopy = getMemberCtaCopy(memberCtaContext);
  if (refs.accountQuickBuyBtn) {
    refs.accountQuickBuyBtn.textContent = ctaCopy.quickAction;
  }
  if (refs.accountQuickBuyTip) {
    refs.accountQuickBuyTip.textContent = "可随时取消，数据仍保留在本地。";
  }

  titleEl.textContent = petOn ? "✨ 升级会员，解锁更多温柔陪伴" : "升级会员，解锁更多实用权益";
  introEl.textContent = ctaCopy.intro;
  listEl.innerHTML = MEMBER_BENEFITS
    .map((item) => `<li><strong>${item.title}</strong><span>${item.desc}</span></li>`)
    .join("");
}

function updatePetRenameCopy() {
  const inputEl = refs.accountPetNicknameInput;
  const btnEl = refs.accountPetNicknameSaveBtn;
  if (!inputEl || !btnEl) return;
  const raw = (inputEl.value || "").trim();
  btnEl.textContent = raw ? `叫你${raw}好吗？` : "快给我起个名字吧，主人。";
  btnEl.classList.toggle("pet-name-ready", Boolean(raw));
}

function playPetRenameFeedback(message) {
  const bubble = refs.accountPetNameFeedback;
  const avatar = refs.accountCenterAvatar;
  const isCenterVisible = Boolean(refs.accountCenterView && !refs.accountCenterView.classList.contains("hidden"));
  if (!bubble || !avatar || !isCenterVisible || !state.settings.petCompanionEnabled) {
    showToast(message);
    return;
  }
  bubble.textContent = message;
  bubble.classList.remove("hidden", "showing");
  avatar.classList.remove("nuzzle");
  void bubble.offsetWidth;
  bubble.classList.add("showing");
  avatar.classList.add("nuzzle");
  if (typeof navigator !== "undefined" && typeof navigator.vibrate === "function") {
    navigator.vibrate([12, 28, 12]);
  }
  setTimeout(() => {
    bubble.classList.add("hidden");
    bubble.classList.remove("showing");
    avatar.classList.remove("nuzzle");
  }, 1800);
}

function renderAccountOverlay() {
  if (accountOverlayView === "member" && state.settings.isMember) {
    accountOverlayView = "center";
  }
  const isLoggedIn = Boolean(state.settings.isLoggedIn);
  const accountName = state.settings.displayName || "叙帐用户";
  if (!isLoggedIn) {
    if (accountOverlayView !== "member") {
      accountOverlayView = "login";
    }
  } else if (accountOverlayView === "login") {
    accountOverlayView = "center";
  }
  refs.accountLoginView.classList.toggle("hidden", accountOverlayView !== "login");
  refs.accountCenterView.classList.toggle("hidden", accountOverlayView !== "center");
  refs.accountMemberView.classList.toggle("hidden", accountOverlayView !== "member");
  if (refs.accountMorePlansBody && refs.accountMorePlansToggle) {
    refs.accountMorePlansBody.classList.toggle("hidden", !memberPlansExpanded);
    refs.accountMorePlansToggle.textContent = memberPlansExpanded ? "收起更多套餐" : "查看更多套餐";
  }
  const petOn = Boolean(state.settings.petCompanionEnabled);
  const usePetTheme = petOn && accountOverlayView === "center";
  const memberTier = String(state.settings.memberTier || "").toLowerCase();
  const memberStateText = !state.settings.isMember
    ? "轻享免费版"
    : memberTier === "monthly"
      ? "月度陪伴中"
      : memberTier === "yearly"
        ? "年度陪伴中"
        : memberTier === "lifetime"
          ? "永久陪伴中"
          : "会员陪伴中";
  refs.accountCenterName.textContent = `你好呀，${accountName}`;
  refs.accountCenterAvatar.textContent = petOn ? "🐱" : "👤";
  refs.accountCenterState.textContent = `当前状态：✨ ${memberStateText}`;
  refs.accountPetNameFeedback?.classList.add("hidden");
  refs.accountPetNameFeedback?.classList.remove("showing");
  refs.accountCenterAvatar?.classList.remove("nuzzle");
  refs.accountCenterView.classList.toggle("member-pet-theme", usePetTheme);
  refs.accountUpgradeEntryBtn.classList.toggle("hidden", state.settings.isMember);
  const showPetNicknameEditor = Boolean(state.settings.isMember && petOn);
  refs.accountPetNicknameInput.closest(".account-petname-field")?.classList.toggle("hidden", !showPetNicknameEditor);
  refs.accountPetNicknameSaveBtn.classList.toggle("hidden", !showPetNicknameEditor);
  refs.accountPetNicknameTip.classList.toggle("hidden", !showPetNicknameEditor);
  refs.accountPetNicknameInput.value = state.settings.userPetNickname || "";
  refs.accountPetNicknameInput.disabled = !showPetNicknameEditor;
  refs.accountPetNicknameSaveBtn.disabled = !showPetNicknameEditor;
  refs.accountPetNicknameTip.textContent = showPetNicknameEditor
    ? "可输入 2-6 个字，保存后将用于宠物包与宠物对话文案。"
    : "升级会员并开启宠物陪伴后可自定义宠物昵称。";
  updatePetRenameCopy();
  if (refs.accountMemberBenefitsToggle && refs.accountMemberBenefitsBody) {
    refs.accountMemberBenefitsToggle.classList.remove("is-open");
    refs.accountMemberBenefitsBody.classList.add("hidden");
  }
  renderAccountCenterBenefits();
  renderMemberUpgradeBenefits();
  if (accountOverlayView === "member" && !state.settings.isMember) {
    const mark = `${memberCtaContext}:${accountOverlayView}`;
    if (memberOverlayExposureMark !== mark) {
      memberOverlayExposureMark = mark;
      trackAnalytics("member_cta_exposed", { source: memberCtaContext, channel: "member_overlay" });
    }
  }
}

function closeMonthlyTrialModal() {
  setUIModal("none");
  refs.monthlyTrialModal.classList.add("hidden");
}

function openDeleteConfirmModal(recordId) {
  if (!recordId) return;
  pendingDeleteRecordId = recordId;
  setUIModal("deleteConfirm");
  refs.deleteConfirmModal?.classList.remove("hidden");
}

function closeDeleteConfirmModal() {
  pendingDeleteRecordId = null;
  setUIModal("none");
  refs.deleteConfirmModal?.classList.add("hidden");
}

function confirmDeleteRecord() {
  const targetId = pendingDeleteRecordId || editingRecordId;
  if (!targetId) {
    closeDeleteConfirmModal();
    return;
  }
  const idx = state.items.findIndex((x) => x.id === targetId);
  closeDeleteConfirmModal();
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
}

function getTodayPlaybackRecords() {
  const todayKey = new Date().toISOString().slice(0, 10);
  return state.items
    .filter((item) => item.createdAt.slice(0, 10) === todayKey)
    .sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt))
    .slice(0, 16);
}

function formatClockTime(dateText) {
  const d = new Date(dateText);
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}

function stopBillPlaybackLoop() {
  if (playbackRafId) {
    cancelAnimationFrame(playbackRafId);
    playbackRafId = null;
  }
  playbackRunning = false;
}

function renderBillPlaybackProgress(progress) {
  const safeProgress = Math.max(0, Math.min(1, progress));
  refs.billPlaybackProgressBar.style.width = `${(safeProgress * 100).toFixed(1)}%`;
  refs.billPlaybackDoneText?.classList.toggle("hidden", safeProgress < 1);
  if (!playbackRecords.length) return;
  const playedCount = Math.floor(safeProgress * playbackRecords.length);
  const nextActive = Math.min(playbackRecords.length - 1, playedCount);
  const rows = refs.billPlaybackTimeline.querySelectorAll("li");
  rows.forEach((row, index) => {
    row.classList.toggle("played", index < playedCount);
    row.classList.toggle("active", index === nextActive && safeProgress < 1);
  });
  if (nextActive !== playbackActiveIndex && rows[nextActive]) {
    rows[nextActive].scrollIntoView({ block: "nearest", behavior: "smooth" });
    playbackActiveIndex = nextActive;
  }
}

function startBillPlayback() {
  if (!playbackRecords.length) return;
  stopBillPlaybackLoop();
  playbackRunning = true;
  playbackStartAt = performance.now() - playbackElapsedBeforePause;
  refs.billPlaybackPauseBtn.textContent = "暂停";
  const DURATION = 10000;
  const tick = (now) => {
    if (!playbackRunning) return;
    const elapsed = now - playbackStartAt;
    playbackElapsedBeforePause = elapsed;
    const progress = Math.min(1, elapsed / DURATION);
    renderBillPlaybackProgress(progress);
    if (progress >= 1) {
      stopBillPlaybackLoop();
      refs.billPlaybackPauseBtn.textContent = "播放";
      trackAnalytics("bill_playback_completed", {
        count: playbackRecords.length,
        duration_ms: 10000,
      });
      showMemberNudge("playback_complete");
      return;
    }
    playbackRafId = requestAnimationFrame(tick);
  };
  playbackRafId = requestAnimationFrame(tick);
}

function pauseBillPlayback() {
  if (!playbackRunning) return;
  stopBillPlaybackLoop();
  refs.billPlaybackPauseBtn.textContent = "播放";
}

function restartBillPlayback() {
  playbackElapsedBeforePause = 0;
  playbackActiveIndex = -1;
  refs.billPlaybackDoneText?.classList.add("hidden");
  renderBillPlaybackProgress(0);
  startBillPlayback();
}

function closeBillPlaybackModal() {
  stopBillPlaybackLoop();
  playbackElapsedBeforePause = 0;
  playbackActiveIndex = -1;
  playbackRecords = [];
  setUIModal("none");
  refs.billPlaybackModal.classList.add("hidden");
}

function openBillPlaybackModal() {
  const records = getTodayPlaybackRecords();
  if (!records.length) {
    trackAnalytics("bill_playback_open_empty");
    showToast("今天还没有账单可回放。");
    return;
  }
  trackAnalytics("bill_playback_open", { count: records.length });
  playbackRecords = records;
  playbackElapsedBeforePause = 0;
  playbackActiveIndex = -1;
  refs.billPlaybackTimeline.innerHTML = "";
  records.forEach((item) => {
    const li = document.createElement("li");
    const emotionTag = item.emotionTag || inferEmotionTag(item);
    li.innerHTML = `
      <div class="bill-playback-row">
        <span>${formatClockTime(item.createdAt)} · ${item.category}</span>
        <span>${formatCNY(item.amount)}</span>
      </div>
      <p class="muted">${item.title} · ${emotionTag}</p>
    `;
    refs.billPlaybackTimeline.appendChild(li);
  });
  refs.billPlaybackProgressBar.style.width = "0%";
  refs.billPlaybackDoneText?.classList.add("hidden");
  refs.billPlaybackPauseBtn.textContent = "暂停";
  setUIModal("billPlayback");
  refs.billPlaybackModal.classList.remove("hidden");
  startBillPlayback();
}

async function generateMonthlyInsight() {
  const TRIAL_TOTAL = 5;
  if (state.isGeneratingMonthlyInsight) return;
  const isMember = Boolean(state.settings.isMember);
  if (!isMember && state.monthlyTrialUsed >= TRIAL_TOTAL) {
    openMonthlyTrialModal(
      "免费次数已用完",
      "您的免费月度复盘次数已用完，升级会员即可解锁无限次月度/季度/年度 AI 复盘，还有更多专属权益等你体验。"
    );
    return;
  }

  const firstTime = !isMember && state.monthlyTrialUsed === 0;
  state.isGeneratingMonthlyInsight = true;
  setAIStatus("monthly", "hidden", "");
  setAIStatus("premium", "hidden", "");
  renderInsight();
  await new Promise((resolve) => setTimeout(resolve, 800));
  const monthKey = thisMonthKey();
  const monthItems = state.items.filter((x) => x.createdAt.startsWith(monthKey));
  const localReport = monthlyInsightPayload();
  const aiReport = await requestAIInsight("monthly", monthItems, `${monthKey.replace("-", "年")}月`);
  const report = aiReport.ok
    ? {
        monthKey: localReport.monthKey,
        summary: aiReport.payload.summary || localReport.summary,
        structure: aiReport.payload.action || localReport.structure,
        advice: aiReport.payload.encourage || localReport.advice,
        createdAt: new Date().toISOString(),
      }
    : localReport;
  if (aiReport.ok) {
    setAIStatus("monthly", "live", getAIStatusText("live"));
    triggerPetMicroAction("blink", "复盘写好啦，给你放在这儿咯～");
  } else {
    setAIStatus(
      "monthly",
      state.settings.remoteAIEnabled ? "error" : "fallback",
      getAIStatusText(state.settings.remoteAIEnabled ? "error" : "fallback")
    );
  }
  state.monthlyInsights = [report, ...state.monthlyInsights.filter((x) => x.monthKey !== report.monthKey)];
  if (!isMember) {
    state.monthlyTrialUsed += 1;
  }
  state.isGeneratingMonthlyInsight = false;
  persist();
  renderInsight();
  trackAnalytics("ai_monthly_generated", {
    mode: aiReport.ok ? "live" : state.settings.remoteAIEnabled ? "error_fallback" : "local_fallback",
    item_count: monthItems.length,
    member: isMember,
  });
  showMemberNudge("ai_monthly");

  if (isMember) {
    showPetBubble(buildAiReviewPetMessage());
    return;
  }

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

async function generatePremiumInsight(label, days) {
  if (!state.settings.isMember) {
    openMonthlyTrialModal("会员专属权益", "季度 / 年度复盘为会员专属权益，升级会员即可解锁。");
    return;
  }
  const report = rangeInsightPayload(days, label);
  setAIStatus("monthly", "hidden", "");
  const end = new Date();
  const start = new Date();
  start.setDate(end.getDate() - (days - 1));
  start.setHours(0, 0, 0, 0);
  const rangeItems = state.items.filter((x) => new Date(x.createdAt) >= start && x.amount > 0);
  const period = days >= 60 ? "monthly" : "weekly";
  const feature = days >= 360 ? "yearly" : "quarterly";
  const aiRange = await requestAIInsight(period, rangeItems, label, feature);
  if (aiRange.ok) {
    report.summary = aiRange.payload.summary || report.summary;
    report.structure = aiRange.payload.action || report.structure;
    report.advice = aiRange.payload.encourage || report.advice;
    setAIStatus("premium", "live", getAIStatusText("live"));
    triggerPetMicroAction("blink", "这段时间的节奏我帮你梳理好啦～");
  } else {
    setAIStatus(
      "premium",
      state.settings.remoteAIEnabled ? "error" : "fallback",
      getAIStatusText(state.settings.remoteAIEnabled ? "error" : "fallback")
    );
  }
  refs.monthlyInsightContent.classList.remove("hidden");
  refs.monthlyInsightSummary.textContent = report.summary;
  refs.monthlyInsightStructure.textContent = report.structure;
  refs.monthlyInsightAdvice.textContent = report.advice;
  renderAIStatus();
  showToast(getToastCopy().insightGenerated(label));
  showPetBubble(buildAiReviewPetMessage());
}

async function generateTodayInsight() {
  if (state.isGeneratingInsight) return;
  state.isGeneratingInsight = true;
  setAIStatus("daily", "hidden", "");
  renderInsight();

  const dayKey = new Date().toISOString().slice(0, 10);
  state.insights = state.insights.filter((x) => x.dayKey !== dayKey);
  const todayItems = state.items.filter((x) => x.createdAt.slice(0, 10) === dayKey);
  const total = todayItems.reduce((sum, x) => sum + x.amount, 0);
  const topCategory = topCategoryFor(todayItems) || "暂无";
  const aiInsight = await requestAIInsight("daily", todayItems, "今日");
  const localFallback = buildLocalDailyInsightFallback(total, topCategory);

  const insight = {
    id: crypto.randomUUID(),
    dayKey,
    summary: aiInsight.ok ? aiInsight.payload.summary : localFallback.summary,
    action: (aiInsight.ok ? aiInsight.payload.action : null) || localFallback.action,
    encourage: (aiInsight.ok ? aiInsight.payload.encourage : null) || localFallback.encourage,
    createdAt: new Date().toISOString(),
  };
  if (aiInsight.ok) {
    setAIStatus("daily", "live", getAIStatusText("live"));
    triggerPetMicroAction("blink", "今日小结出炉啦，快看看～");
  } else {
    setAIStatus(
      "daily",
      state.settings.remoteAIEnabled ? "error" : "fallback",
      getAIStatusText(state.settings.remoteAIEnabled ? "error" : "fallback")
    );
  }
  state.insights.unshift(insight);
  state.isGeneratingInsight = false;
  persist();
  render();
  trackAnalytics("ai_daily_generated", {
    mode: aiInsight.ok ? "live" : state.settings.remoteAIEnabled ? "error_fallback" : "local_fallback",
    item_count: todayItems.length,
  });
  showPetBubble(buildAiReviewPetMessage());
}

function topCategoryFor(items) {
  const map = {};
  items.forEach((item) => {
    map[item.category] = (map[item.category] || 0) + item.amount;
  });
  return Object.entries(map).sort((a, b) => b[1] - a[1])[0]?.[0];
}

function buildHomeStoryNarrative(todayItems) {
  const count = todayItems.length;
  const todayTotal = todayItems.reduce((sum, x) => sum + x.amount, 0);
  const topCategory = topCategoryFor(todayItems);

  if (count === 0) {
    return {
      title: "今天先记下来",
      subtitle: "晚上再回头看，这一天会慢慢有轮廓。",
    };
  }
  if (count === 1) {
    const item = todayItems[0];
    const tag = item.emotionTag || inferEmotionTag(item);
    return {
      title: "今天的第一笔小痕迹",
      subtitle: `${tag}，这一天刚翻开第一页。`,
    };
  }
  if (count === 2) {
    return {
      title: "今天已留下 2 段小痕迹",
      subtitle: topCategory
        ? `主要在「${topCategory}」上，轮廓慢慢变得具体。`
        : "两笔小账落下来，今天开始有了形状。",
    };
  }
  if (count === 3) {
    return {
      title: "今天留下了 3 段小痕迹",
      subtitle: todayTotal > 0
        ? `合计 ${formatCNY(todayTotal)}，几笔小账轻轻串起今天。`
        : "三笔落下来，这一天正在变得可看。",
    };
  }
  return {
    title: `今天留下了 ${count} 段小痕迹`,
    subtitle: topCategory
      ? `「${topCategory}」居多，几笔小账轻轻留住今天怎样过的。`
      : "几笔小账不是评判，只是把今天怎样过的，轻轻留住。",
  };
}

function renderHome() {
  const copy = getExperienceCopy();
  const todayKey = new Date().toISOString().slice(0, 10);
  const todayItems = state.items.filter((x) => x.createdAt.slice(0, 10) === todayKey);
  const weekItems = state.items.filter((x) => sameWeek(x.createdAt));
  const todayTotal = todayItems.reduce((sum, x) => sum + x.amount, 0);
  const weekTotal = weekItems.reduce((sum, x) => sum + x.amount, 0);

  refs.todayTotal.textContent = formatCNY(todayTotal);
  refs.weekTotal.textContent = `本周累计 ${formatCNY(weekTotal)}`;
  const homeStory = buildHomeStoryNarrative(todayItems);
  if (refs.homeStoryTitle) {
    refs.homeStoryTitle.textContent = homeStory.title;
  }
  if (refs.homeStorySubtitle) {
    refs.homeStorySubtitle.textContent = homeStory.subtitle;
  }

  refs.homeTodayList.innerHTML = "";
  if (refs.homePlaybackEntryBtn) {
    refs.homePlaybackEntryBtn.disabled = todayItems.length === 0;
  }
  if (refs.homePlaybackEntryHint) {
    refs.homePlaybackEntryHint.textContent = todayItems.length ? "十几秒叙完今天" : "有记录后可播放";
  }
  const recent = [...todayItems]
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
    .slice(0, 3);
  refs.homeTodayEmptyArt.classList.toggle("hidden", recent.length > 0);
  recent.forEach((item) => {
    const emotionTag = item.emotionTag || inferEmotionTag(item);
    const li = document.createElement("li");
    li.className = "home-record-item";
    li.tabIndex = 0;
    li.innerHTML = `
      <div class="item-title-row">
        <span>${item.title}</span>
        <span>${formatCNY(item.amount)}</span>
      </div>
      <p class="emotion-tag">${emotionTag}</p>
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
  if (refs.homeInsightSummary) {
    refs.homeInsightSummary.textContent = todayInsight ? `${todayInsight.summary} ${todayInsight.action}` : copy.homeInsightEmpty;
    refs.homeInsightSummary.classList.toggle("muted", !todayInsight);
    refs.homeInsightSummary.classList.toggle("compact", Boolean(todayInsight));
  }
  if (refs.homeInsightHint) {
    refs.homeInsightHint.textContent = "";
  }
  if (isLatestActionCardExpired(state.latestActionCard)) {
    state.latestActionCard = null;
    persist();
  }
  const homeActionText = state.latestActionCard?.text || "";
  refs.homeActionCard.classList.remove("hidden");
  refs.homeActionCardText.textContent = homeActionText || "随手记几笔，这里会慢慢长出你的生活痕迹。";
  refs.homeActionCardMeta.textContent = homeActionText ? formatRelativeTime(state.latestActionCard?.updatedAt || "") : "";
}

function resetRecordEditorState() {
  editingRecordId = null;
  refs.recordFormTitle.textContent = "记下这一笔";
  refs.deleteRecordBtn.classList.add("hidden");
}

function startNewManualRecordDraft() {
  resetRecordEditorState();
  state.recordMode = "manual";
  refs.titleInput.value = "";
  amountStream = { intPart: "", decPart: "", hasDot: false };
  updateAmountInputFromStream();
  selectedCategory = topCategoryFromHistory();
  categoryLockedByUser = false;
  recordDetailsExpanded = false;
  refs.noteSuggestions.classList.add("hidden");
  refs.noteSuggestions.innerHTML = "";
  refs.recordDateInput.value = new Date().toISOString().slice(0, 10);
  scenePackExpanded = false;
  renderRecord();
}

function openRecordEditor(recordId) {
  const item = state.items.find((x) => x.id === recordId);
  if (!item) return;
  editingRecordId = recordId;
  state.recordMode = "manual";
  refs.recordFormTitle.textContent = "调整这一笔";
  refs.deleteRecordBtn.classList.remove("hidden");
  refs.titleInput.value = item.title || "";
  amountStream = parseAmountTextToStream(String(item.amount.toFixed(2)));
  updateAmountInputFromStream();
  selectedCategory = item.category || "其他";
  categoryLockedByUser = true;
  refs.recordDateInput.value = item.createdAt.slice(0, 10);
  recordDetailsExpanded = true;
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
  refs.amountQuickKeyboard?.classList.toggle(
    "hidden",
    !(state.recordMode === "manual" && (isAmountInputFocused || hasAmountStreamValue()))
  );
  refs.recordFormTitle.textContent = editingRecordId ? "调整这一笔" : "记下这一笔";
  if (state.recordMode !== "manual") {
    renderOCRDraftArea();
    return;
  }

  const wasDisabled = refs.saveRecordBtn.disabled;
  if (isEditing) {
    recordDetailsExpanded = true;
  }
  refs.categoryField.classList.toggle("hidden", !amountReady && !isEditing);
  refs.noteField.classList.toggle("hidden", !amountReady && !isEditing);
  refs.amountAssist.classList.toggle("hidden", amountReady || isEditing);
  refs.networkHint.classList.toggle("hidden", !amountReady || !state.settings.remoteAIEnabled || isEditing);
  refs.dateHint.classList.toggle("hidden", !amountReady && !isEditing);
  refs.localPrivacyHint.classList.toggle("hidden", !amountReady && !isEditing);
  refs.editDateBtn.classList.toggle("hidden", !amountReady && !isEditing);
  refs.saveRecordBtn.disabled = !amountReady;
  refs.saveRecordBtn.textContent = isEditing ? "更新这一笔" : "放进账本";
  toggleRecordDetails(recordDetailsExpanded && (amountReady || isEditing));
  updateLifeEntryPreview();
  refs.prefillDemoButtons?.forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.prefillMode === prefillDemoMode);
  });
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
  updateLifeEntryPreview();
}

function renderStats() {
  let period = state.period || "month";
  if (period === "custom") {
    const start = state.billCustomRangeStart;
    const end = state.billCustomRangeEnd;
    if (!start || !end || start > end) {
      period = "month";
      state.period = "month";
      persist();
    }
  }
  const category = refs.billCategoryFilter.value;
  const periodRange = getBillRangeForMode(period);
  const rangeStart = periodRange?.start || "";
  const rangeEnd = periodRange?.end || "";

  const categoryOptions = ["", ...new Set(state.items.map((x) => x.category))];
  const currentSelect = refs.billCategoryFilter.value;
  refs.billCategoryFilter.innerHTML = categoryOptions
    .map((c) => `<option value="${c}">${c || "全部分类"}</option>`)
    .join("");
  refs.billCategoryFilter.value = currentSelect && categoryOptions.includes(currentSelect) ? currentSelect : "";

  let filtered = state.items.filter((item) => {
    const day = String(item.createdAt || "").slice(0, 10);
    if (!day || (rangeStart && day < rangeStart) || (rangeEnd && day > rangeEnd)) return false;
    if (category && item.category !== category) return false;
    return item.amount > 0;
  });

  filtered = filtered.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

  const expenseTotal = filtered.filter((x) => x.amount > 0).reduce((sum, x) => sum + x.amount, 0);
  refs.billExpenseTotal.textContent = formatCNY(expenseTotal);
  renderBillTrendChart(filtered, period);

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
  updateBillCustomRangeBtnText();
  updateDebugHUD(`render-stats:${filtered.length}`);
}

function renderBillTrendChart(sourceItems = [], period = "month") {
  const today = new Date();
  const totalsByDay = [];
  const labels = [];

  if (period === "year") {
    const currentMonth = today.getMonth();
    for (let m = 0; m <= currentMonth; m += 1) {
      const total = sourceItems
        .filter((item) => {
          const d = new Date(item.createdAt);
          return d.getFullYear() === today.getFullYear() && d.getMonth() === m;
        })
        .reduce((sum, item) => sum + item.amount, 0);
      totalsByDay.push(total);
      labels.push(`${m + 1}月`);
    }
  } else {
    let start = new Date(today);
    if (period === "week") {
      start.setDate(today.getDate() - ((today.getDay() + 6) % 7));
    } else if (period === "custom" && state.billCustomRangeStart && state.billCustomRangeEnd) {
      start = new Date(`${state.billCustomRangeStart}T00:00:00`);
      const end = new Date(`${state.billCustomRangeEnd}T00:00:00`);
      const cursor = new Date(start);
      while (cursor <= end) {
        const key = cursor.toISOString().slice(0, 10);
        const total = sourceItems
          .filter((item) => item.createdAt.slice(0, 10) === key)
          .reduce((sum, item) => sum + item.amount, 0);
        totalsByDay.push(total);
        labels.push(key);
        cursor.setDate(cursor.getDate() + 1);
      }
    } else {
      start = new Date(today.getFullYear(), today.getMonth(), 1);
    }

    if (period !== "custom") {
      const cursor = new Date(start);
      while (cursor <= today) {
        const key = cursor.toISOString().slice(0, 10);
        const total = sourceItems
          .filter((item) => item.createdAt.slice(0, 10) === key)
          .reduce((sum, item) => sum + item.amount, 0);
        totalsByDay.push(total);
        labels.push(key);
        cursor.setDate(cursor.getDate() + 1);
      }
    }
  }

  const safeTotals = totalsByDay.length ? totalsByDay : [0];
  const max = Math.max(...safeTotals, 1);
  const width = 300;
  const height = 90;
  const padX = 8;
  const padY = 8;
  const innerW = width - padX * 2;
  const innerH = height - padY * 2;
  const points = safeTotals
    .map((value, idx) => {
      const denominator = Math.max(1, safeTotals.length - 1);
      const x = padX + (idx / denominator) * innerW;
      const y = padY + innerH - (value / max) * innerH;
      return `${x.toFixed(2)},${y.toFixed(2)}`;
    })
    .join(" ");
  refs.billTrendLine.setAttribute("points", points);
  const peakValue = Math.max(...safeTotals);
  const peakIndex = safeTotals.indexOf(peakValue);
  const peakDenominator = Math.max(1, safeTotals.length - 1);
  const peakX = padX + (peakIndex / peakDenominator) * innerW;
  const peakY = padY + innerH - (peakValue / max) * innerH;
  refs.billTrendPeakDot.setAttribute("cx", peakX.toFixed(2));
  refs.billTrendPeakDot.setAttribute("cy", peakY.toFixed(2));
  refs.billTrendPeakLabel.setAttribute("x", Math.min(width - 76, peakX + 6).toFixed(2));
  refs.billTrendPeakLabel.setAttribute("y", Math.max(14, peakY - 6).toFixed(2));
  refs.billTrendPeakLabel.textContent = formatCNY(peakValue);
  refs.billTrendMaxLabel.textContent = formatCNY(max);
  if (refs.billTrendStartLabel) {
    refs.billTrendStartLabel.textContent =
      period === "year" ? "1月" : period === "week" ? "周初" : period === "custom" ? "起始" : "月初";
  }
  if (refs.billTrendEndLabel) {
    refs.billTrendEndLabel.textContent = period === "year" ? "本月" : "今天";
  }

  const recent7 = safeTotals.slice(-7).reduce((sum, x) => sum + x, 0);
  const prev7 = safeTotals.slice(-14, -7).reduce((sum, x) => sum + x, 0);
  if (recent7 > prev7 * 1.15) {
    refs.billTrendInsight.textContent = "最近一周支出有上升趋势，建议关注高频消费分类。";
  } else if (recent7 < prev7 * 0.85) {
    refs.billTrendInsight.textContent = "最近一周支出明显回落，当前消费节奏更稳了。";
  } else {
    refs.billTrendInsight.textContent = "本月支出整体平稳，保持记录就很棒。";
  }
}

function renderInsight() {
  const copy = getExperienceCopy();
  const TRIAL_TOTAL = 5;
  const todayKey = new Date().toISOString().slice(0, 10);
  const todayInsight = state.insights.find((x) => x.dayKey === todayKey);
  if (state.isGeneratingInsight) {
    refs.insightSummary.textContent = " ";
    refs.insightAction.textContent = " ";
    refs.insightEncourage.textContent = " ";
  } else {
    refs.insightSummary.textContent = todayInsight ? todayInsight.summary : copy.dailyInsightEmpty;
    refs.insightAction.textContent = todayInsight ? todayInsight.action : "";
    refs.insightEncourage.textContent = todayInsight ? todayInsight.encourage : "";
  }
  refs.insightSummary.classList.toggle("skeleton-line", state.isGeneratingInsight);
  refs.insightAction.classList.toggle("skeleton-line", state.isGeneratingInsight);
  refs.insightEncourage.classList.toggle("skeleton-line", state.isGeneratingInsight);
  refs.insightSummary.classList.toggle("skeleton-w-100", state.isGeneratingInsight);
  refs.insightAction.classList.toggle("skeleton-w-90", state.isGeneratingInsight);
  refs.insightEncourage.classList.toggle("skeleton-w-72", state.isGeneratingInsight);

  refs.insightHistory.innerHTML = "";
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 6);
  sevenDaysAgo.setHours(0, 0, 0, 0);
  const weekItems = state.items.filter((item) => new Date(item.createdAt) >= sevenDaysAgo && item.amount > 0);
  refs.insightHistoryEmpty.style.display = weekItems.length ? "none" : "block";

  if (weekItems.length) {
    const weeklyReport = rangeInsightPayload(7, "近7天");
    const li = document.createElement("li");
    li.innerHTML = `
      <div class="item-title-row"><span>${new Date().toISOString().slice(0, 10)}</span><span>${copy.weeklyHistoryTag}</span></div>
      <p>${weeklyReport.summary}</p>
      <p class="muted">${weeklyReport.structure}</p>
      <p class="muted">${weeklyReport.advice}</p>
    `;
    refs.insightHistory.appendChild(li);
  }

  refs.generateInsightBtn.disabled = state.isGeneratingInsight;
  refs.generateInsightBtn.textContent = state.isGeneratingInsight ? copy.insightBtnLoading : copy.insightBtnIdle;
  refs.generateInsightBtn.classList.toggle("generating", state.isGeneratingInsight);

  const monthKey = thisMonthKey();
  const monthlyReport = state.monthlyInsights.find((x) => x.monthKey === monthKey) || state.monthlyInsights[0];
  const left = Math.max(0, TRIAL_TOTAL - state.monthlyTrialUsed);
  const isMember = Boolean(state.settings.isMember);
  const isMonthlyLocked = !isMember && left === 0;
  refs.monthlyTrialText.classList.toggle("hidden", isMember);
  if (!isMember) {
    refs.monthlyTrialText.textContent = `剩余试用次数：${left}/${TRIAL_TOTAL}`;
  }
  refs.generateMonthlyInsightBtn.disabled = state.isGeneratingMonthlyInsight;
  refs.generateMonthlyInsightBtn.classList.toggle("generating", state.isGeneratingMonthlyInsight);
  refs.generateMonthlyInsightBtn.classList.toggle("primary-btn", !isMonthlyLocked);
  refs.generateMonthlyInsightBtn.classList.toggle("locked-report-btn", isMonthlyLocked);
  if (state.isGeneratingMonthlyInsight) {
    refs.generateMonthlyInsightBtn.textContent = copy.monthlyBtnLoading;
  } else if (isMonthlyLocked) {
    refs.generateMonthlyInsightBtn.innerHTML = copy.monthlyBtnLocked;
  } else {
    refs.generateMonthlyInsightBtn.textContent = copy.monthlyBtnIdle;
  }
  refs.monthlyInsightContent.classList.toggle("hidden", !monthlyReport && !state.isGeneratingMonthlyInsight);
  if (state.isGeneratingMonthlyInsight) {
    refs.monthlyInsightSummary.textContent = " ";
    refs.monthlyInsightStructure.textContent = " ";
    refs.monthlyInsightAdvice.textContent = " ";
  } else if (monthlyReport) {
    refs.monthlyInsightSummary.textContent = monthlyReport.summary;
    refs.monthlyInsightStructure.textContent = monthlyReport.structure;
    refs.monthlyInsightAdvice.textContent = monthlyReport.advice;
  }
  refs.monthlyInsightSummary.classList.toggle("skeleton-line", state.isGeneratingMonthlyInsight);
  refs.monthlyInsightStructure.classList.toggle("skeleton-line", state.isGeneratingMonthlyInsight);
  refs.monthlyInsightAdvice.classList.toggle("skeleton-line", state.isGeneratingMonthlyInsight);
  refs.monthlyInsightSummary.classList.toggle("skeleton-w-100", state.isGeneratingMonthlyInsight);
  refs.monthlyInsightStructure.classList.toggle("skeleton-w-92", state.isGeneratingMonthlyInsight);
  refs.monthlyInsightAdvice.classList.toggle("skeleton-w-76", state.isGeneratingMonthlyInsight);
  const showWeeklyActions = weekItems.length > 0 && !state.isGeneratingInsight;
  [refs.weeklyRhythmBtn, refs.weeklyShareBtn, refs.weeklyTagBtn].forEach((btn) => {
    if (!btn) return;
    btn.classList.toggle("hidden", !showWeeklyActions);
    btn.disabled = !showWeeklyActions;
  });
  const showMonthlyActions = Boolean(monthlyReport) && !state.isGeneratingMonthlyInsight;
  [refs.monthlySoftPlanBtn, refs.monthlySaveSummaryBtn, refs.monthlyToneSwitchBtn].forEach((btn) => {
    if (!btn) return;
    btn.classList.toggle("hidden", !showMonthlyActions);
    btn.disabled = !showMonthlyActions;
  });
  if (refs.advancedInsightToggleBtn && refs.advancedInsightActions) {
    refs.advancedInsightToggleBtn.textContent = advancedInsightExpanded ? "收起更多复盘" : "查看更多复盘";
    refs.advancedInsightActions.classList.toggle("hidden", !advancedInsightExpanded);
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
  renderAIStatus();
}

function renderSettings() {
  const accountName = state.settings.displayName || "叙帐用户";
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
  refs.weatherNeutralSwitch.checked = state.settings.weatherCompanionEnabled;
  const petModeOn = state.settings.petCompanionEnabled;
  refs.weatherCompanionRow.classList.toggle("hidden", !petModeOn);
  refs.weatherCompanionHelper.classList.toggle("hidden", !petModeOn);
  refs.weatherNeutralRow.classList.toggle("hidden", petModeOn);
  refs.weatherNeutralHelper.classList.toggle("hidden", petModeOn);
}

function render() {
  safeRender("render:theme", () => applyTheme(), { toastMessage: "" });
  safeRender("render:home", () => renderHome());
  safeRender("render:record", () => renderRecord());
  safeRender("render:stats", () => renderStats());
  safeRender("render:insight", () => renderInsight());
  safeRender("render:settings", () => renderSettings());
}

function runStabilitySmokeChecks() {
  const activePage = Object.entries(refs.pages).find(([, el]) => el?.classList.contains("active"))?.[0] || "none";
  const activeTab = refs.tabs.find((btn) => btn.classList.contains("active"))?.dataset.tab || "none";
  return [
    { id: "tab-sync", pass: uiRuntimeState.tab === currentTab && currentTab === activePage && currentTab === activeTab },
    { id: "modal-state", pass: UI_MODALS.has(uiRuntimeState.modal) },
    { id: "input-focus-state", pass: UI_INPUT_FOCUS.has(uiRuntimeState.inputFocus) },
    { id: "stats-render-safe", pass: Boolean(refs.billExpenseTotal && refs.billRecordsList && refs.billRecordsEmpty) },
    { id: "record-render-safe", pass: Boolean(refs.saveRecordBtn && refs.amountInput && refs.categoryOptions) },
    { id: "insight-render-safe", pass: Boolean(refs.generateInsightBtn && refs.insightSummary) },
    { id: "overlay-lock-safe", pass: typeof syncOverlayScrollLock === "function" },
    { id: "safe-render-enabled", pass: typeof safeRender === "function" },
  ];
}

function openGuide() {
  setUIModal("guide");
  guideStep = 1;
  refs.guideOverlay.classList.remove("hidden");
  renderGuideStep();
}

function closeGuide(done = false) {
  setUIModal("none");
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
  ensureMemberNudgePolicyForEnv();
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
    updateLifeEntryPreview();
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
    setUIInputFocus("amount");
    renderAmountDisplay();
    refs.amountQuickKeyboard?.classList.remove("hidden");
    setTimeout(() => {
      refs.amountInput.scrollIntoView({ behavior: "smooth", block: "center" });
    }, 120);
  });
  refs.amountInput.addEventListener("blur", () => {
    document.querySelector(".app-shell")?.classList.remove("keyboard-active");
    isAmountInputFocused = false;
    setUIInputFocus("none");
    renderAmountDisplay();
    renderRecord();
  });
  refs.amountQuickKeyboard?.addEventListener("pointerdown", (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) return;
    const action = target.dataset.amountAction;
    if (!action) return;
    event.preventDefault();
    applyAmountQuickAction(action);
    refs.amountInput?.focus();
  });
  refs.titleInput.addEventListener("input", () => {
    setUIInputFocus("title");
    renderNoteSuggestions();
    updateLifeEntryPreview();
    if (!editingRecordId) {
      scheduleCategoryRecommendation();
    }
  });
  refs.titleInput.addEventListener("blur", () => {
    setUIInputFocus("none");
    setTimeout(() => {
      refs.noteSuggestions.classList.add("hidden");
    }, 120);
  });
  refs.recordDetailsToggle?.addEventListener("click", () => {
    toggleRecordDetails();
  });
  refs.prefillDemoButtons?.forEach((btn) => {
    btn.addEventListener("click", () => {
      prefillDemoMode = btn.dataset.prefillMode || "generic";
      refs.titleInput.value = "";
      updateLifeEntryPreview();
      renderRecord();
    });
  });
  refs.tabs.forEach((btn) =>
    btn.addEventListener("click", () => {
      if (btn.dataset.tab === "record" && editingRecordId) {
        startNewManualRecordDraft();
      }
      switchTab(btn.dataset.tab);
    })
  );
  refs.jumpButtons.forEach((btn) =>
    btn.addEventListener("click", () => {
      if (btn.dataset.jump === "record" && editingRecordId) {
        startNewManualRecordDraft();
      }
      switchTab(btn.dataset.jump);
    })
  );
  refs.quickManualBtn?.addEventListener("click", () => {
    startNewManualRecordDraft();
    switchTab("record");
  });

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

  refs.billCategoryFilter.addEventListener("change", renderStats);
  refs.billDateFilterBtn.addEventListener("click", openBillDateRangeModal);
  refs.billDateRangeCloseBtn.addEventListener("click", closeBillDateRangeModal);
  refs.billPresetWeekBtn.addEventListener("click", () => {
    billRangeDraftMode = "week";
    fillBillDateInputsByPreset("week");
    renderBillDateRangeSelectionUI("week");
    triggerPetMicroAction("nod");
  });
  refs.billPresetMonthBtn.addEventListener("click", () => {
    billRangeDraftMode = "month";
    fillBillDateInputsByPreset("month");
    renderBillDateRangeSelectionUI("month");
    triggerPetMicroAction("nod");
  });
  refs.billPresetYearBtn.addEventListener("click", () => {
    billRangeDraftMode = "year";
    fillBillDateInputsByPreset("year");
    renderBillDateRangeSelectionUI("year");
    triggerPetMicroAction("nod");
  });
  [refs.billDateRangeStartInput, refs.billDateRangeEndInput].forEach((el) => {
    el.addEventListener("change", () => {
      billRangeDraftMode = "custom";
      renderBillDateRangeSelectionUI("custom");
    });
  });
  refs.billDateRangeConfirmBtn.addEventListener("click", () => {
    const start = refs.billDateRangeStartInput.value;
    const end = refs.billDateRangeEndInput.value;
    if (!start || !end) {
      showToast("请先选择开始和结束日期");
      return;
    }
    if (start > end) {
      showToast("开始日期不能晚于结束日期");
      return;
    }
    state.period = billRangeDraftMode === "custom" ? "custom" : billRangeDraftMode;
    if (state.period === "custom") {
      state.billCustomRangeStart = start;
      state.billCustomRangeEnd = end;
    }
    renderBillDateRangeSelectionUI(state.period);
    persist();
    closeBillDateRangeModal();
    renderStats();
  });
  refs.billDateRangeModal.addEventListener("click", (event) => {
    if (event.target === refs.billDateRangeModal) {
      closeBillDateRangeModal();
    }
  });

  refs.saveRecordBtn.addEventListener("click", async () => {
    updateDebugHUD("save-click-start");
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
        current.emotionTag = inferEmotionTag({ category: finalCategory, amount });
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
      recordDetailsExpanded = false;
      prefillDemoMode = "generic";
      resetRecordEditorState();
      updateCategoryUI();
      refs.noteSuggestions.classList.add("hidden");
      refs.noteSuggestions.innerHTML = "";
      refs.recordDateInput.value = new Date().toISOString().slice(0, 10);
      goHomeAfterSave();
      showToast(wasEditing ? "账单已更新" : "手动记录已保存");
      updateDebugHUD("save-ok");
      setTimeout(() => {
        triggerPetMicroAction("stamp", "啪叽盖章，记进小本本啦～");
      }, 160);
      if (!wasEditing) {
        const streakDays = consecutiveRecordDays();
        const recordText =
          streakDays >= 2
            ? pickRandom(petCopy.streak).replace("{days}", String(streakDays))
            : await buildContextualPetMessage(draftRecordContext);
        setTimeout(() => showPetBubble(recordText), 120);
        return;
      }
    }
  });
  refs.deleteRecordBtn.addEventListener("click", () => {
    if (!editingRecordId) return;
    openDeleteConfirmModal(editingRecordId);
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
  refs.weeklyRhythmBtn?.addEventListener("click", () => {
    const result = buildWeeklyRhythmText();
    state.weeklyActionCard = result;
    setLatestActionCard(result, { scope: "weekly" });
    persist();
    renderHome();
    showToast("已整理本周节奏，可在首页行动卡回看。");
  });
  refs.weeklyShareBtn?.addEventListener("click", async () => {
    const ok = await downloadWeeklyShareCardImage();
    if (!ok) return;
    trackAnalytics("weekly_share_card_generated", {
      with_records: getTodayPlaybackRecords().length > 0,
      mode: isPetModeActive() ? "pet" : "neutral",
    });
    showMemberNudge("share_success");
    if (isPetModeActive()) {
      showToast("周度分享卡图片已生成并开始下载。");
      showPetBubble("喵～又记录了一周的生活，你真棒！");
    } else {
      showToast("这周的生活已归档，谢谢你的认真记录。");
    }
  });
  refs.weeklyTagBtn?.addEventListener("click", () => {
    const topCategory = topSpendCategoryWithin(7);
    const result = `常花类目回看：这周更常记录「${topCategory}」，后续复盘会更清晰。`;
    state.weeklyActionCard = result;
    setLatestActionCard(result, { scope: "weekly" });
    persist();
    renderHome();
    showToast(`已标记常花类目：${topCategory}。`);
  });
  refs.monthlySoftPlanBtn?.addEventListener("click", () => {
    const result = buildMonthlySoftPlanText();
    state.monthlyActionCard = result;
    setLatestActionCard(result, { scope: "monthly" });
    persist();
    renderHome();
    showToast("柔和下月参考已生成，已放到首页卡片。");
  });
  refs.monthlySaveSummaryBtn?.addEventListener("click", () => {
    const monthKey = thisMonthKey();
    const monthlyReport = state.monthlyInsights.find((x) => x.monthKey === monthKey) || state.monthlyInsights[0];
    if (!monthlyReport) {
      showToast("先生成月度复盘，再保存小结。");
      return;
    }
    const result = `月度小结：${monthlyReport.summary}`;
    state.monthlyActionCard = result;
    setLatestActionCard(result, { scope: "monthly" });
    persist();
    renderHome();
    showToast("月度小结已保存到首页行动卡。");
  });
  refs.monthlyToneSwitchBtn?.addEventListener("click", () => {
    showToast("已切换叙述风格，给你另一种温柔表达。");
    generateMonthlyInsight();
  });
  refs.advancedInsightToggleBtn?.addEventListener("click", () => {
    advancedInsightExpanded = !advancedInsightExpanded;
    renderInsight();
  });
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
  refs.petBtn.addEventListener("click", async () => {
    if (petLongPressTriggered) return;
    if (state.settings.weatherCompanionEnabled && !hasWeatherPermissionReady()) {
      if (shouldNudgeWeather()) {
        showPetBubble("定位权限还没准备好，先用通用提醒陪你呀～");
      } else {
        showPetBubble(pickRandom([...petCopy.companion, ...petCopy.lightScene]));
      }
      return;
    }
    if (state.settings.weatherCompanionEnabled) {
      const weather = await fetchWeatherSnapshot();
      const recordLike = { createdAt: new Date().toISOString() };
      const sceneText = pickSceneLocalPetMessage(recordLike, weather);
      if (sceneText) {
        showPetBubble(sceneText);
        return;
      }
    }
    if (state.settings.weatherCompanionEnabled && state.settings.remoteAIEnabled) {
      const canCallAI = shouldCallWeatherAIPet("click");
      if (canCallAI) {
        const weatherAiText = await buildWeatherSpendPetMessage("click");
        showPetBubble(weatherAiText);
        return;
      }
    }
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
    showToast(getToastCopy().memberEntryHint);
  });
  refs.monthlyTrialModal.addEventListener("click", (event) => {
    if (event.target === refs.monthlyTrialModal) {
      closeMonthlyTrialModal();
    }
  });
  refs.homePlaybackEntryBtn?.addEventListener("click", openBillPlaybackModal);
  refs.billPlaybackCloseBtn?.addEventListener("click", closeBillPlaybackModal);
  refs.billPlaybackPauseBtn?.addEventListener("click", () => {
    if (playbackRunning) {
      pauseBillPlayback();
    } else {
      startBillPlayback();
    }
  });
  refs.billPlaybackRestartBtn?.addEventListener("click", restartBillPlayback);
  refs.billPlaybackModal?.addEventListener("click", (event) => {
    if (event.target === refs.billPlaybackModal) {
      closeBillPlaybackModal();
    }
  });
  refs.deleteConfirmCancelBtn.addEventListener("click", closeDeleteConfirmModal);
  refs.deleteConfirmOkBtn.addEventListener("click", confirmDeleteRecord);
  refs.deleteConfirmModal.addEventListener("click", (event) => {
    if (event.target === refs.deleteConfirmModal) {
      closeDeleteConfirmModal();
    }
  });

  refs.displayNameInput.addEventListener("input", (e) => {
    state.settings.displayName = e.target.value.trim() || "叙帐用户";
    persist();
    renderHome();
    renderSettings();
    renderAccountOverlay();
  });
  refs.accountEntryBtn.addEventListener("click", () => {
    openAccountOverlay();
  });
  refs.memberNudgeBtn?.addEventListener("click", () => {
    trackAnalytics("member_cta_clicked", { source: memberCtaContext, channel: "nudge_bar" });
    closeBillPlaybackModal();
    hideMemberNudge();
    openMemberOffer(memberCtaContext);
  });
  refs.memberNudgeDismissBtn?.addEventListener("click", () => {
    markMemberNudgeDismissed(memberCtaContext);
    trackAnalytics("member_cta_dismissed", { source: memberCtaContext, channel: "nudge_bar" });
    hideMemberNudge();
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
    showToast(getToastCopy().loginSuccess);
  };
  refs.accountPhoneLoginBtn.addEventListener("click", mockLogin);
  refs.accountWechatLoginBtn.addEventListener("click", mockLogin);
  refs.memberScenePackEntryBtn.addEventListener("click", () => {
    openAccountOverlay();
    memberPlansExpanded = false;
    accountOverlayView = state.settings.isMember ? "center" : "member";
    renderAccountOverlay();
  });
  refs.accountUpgradeEntryBtn.addEventListener("click", () => {
    memberCtaContext = "settings_center";
    memberPlansExpanded = false;
    trackAnalytics("member_cta_clicked", { source: memberCtaContext, channel: "account_center" });
    accountOverlayView = "member";
    renderAccountOverlay();
  });
  refs.accountQuickBuyBtn?.addEventListener("click", () => {
    trackAnalytics("member_cta_clicked", { source: memberCtaContext, channel: "member_hero" });
    refs.buyYearlyBtn?.scrollIntoView({ behavior: "smooth", block: "center" });
    setTimeout(() => refs.buyYearlyBtn?.focus(), 220);
  });
  refs.accountMorePlansToggle?.addEventListener("click", () => {
    memberPlansExpanded = !memberPlansExpanded;
    renderAccountOverlay();
  });
  refs.accountMemberBenefitsToggle?.addEventListener("click", () => {
    const shouldOpen = refs.accountMemberBenefitsBody?.classList.contains("hidden");
    refs.accountMemberBenefitsBody?.classList.toggle("hidden", !shouldOpen);
    refs.accountMemberBenefitsToggle?.classList.toggle("is-open", Boolean(shouldOpen));
  });
  refs.accountMemberBackBtn.addEventListener("click", () => {
    accountOverlayView = "center";
    renderAccountOverlay();
  });
  const tryUpgrade = (planName, tier) => {
    trackAnalytics("member_pay_sheet_opened", { source: memberCtaContext, tier, plan_name: planName });
    if (!window.confirm(getDialogCopy().upgradeConfirm)) return;
    state.settings.isLoggedIn = true;
    state.settings.isMember = true;
    state.settings.memberTier = tier;
    persist();
    accountOverlayView = "center";
    renderSettings();
    renderInsight();
    renderAccountOverlay();
    hideMemberNudge();
    showToast(getToastCopy().upgradeSuccess(planName));
    trackAnalytics("member_upgrade_success", { tier, plan_name: planName });
  };
  refs.buyMonthlyBtn.addEventListener("click", () => tryUpgrade("月度会员", "monthly"));
  refs.buyYearlyBtn.addEventListener("click", () => tryUpgrade("年度会员", "yearly"));
  refs.buyLifetimeBtn.addEventListener("click", () => tryUpgrade("永久会员", "lifetime"));
  refs.accountBindPhoneBtn.addEventListener("click", () => {
    showToast("绑定手机号功能开发中");
  });
  refs.accountPetNicknameSaveBtn.addEventListener("click", () => {
    if (!state.settings.isMember) {
      showToast("升级会员后可自定义宠物昵称");
      return;
    }
    const nextName = (refs.accountPetNicknameInput.value || "").trim();
    const isValidName = /^[\u4e00-\u9fa5A-Za-z0-9]{2,6}$/.test(nextName);
    if (!isValidName) {
      playPetRenameFeedback("唔… 换个名字好不好？");
      return;
    }
    const previousName = (state.settings.userPetNickname || "").trim();
    state.settings.userPetNickname = nextName;
    persist();
    renderAccountOverlay();
    renderMemberScenePacks();
    if (!previousName) {
      playPetRenameFeedback("好喜欢这个名字呀！主人～🐾");
      return;
    }
    if (previousName !== nextName) {
      playPetRenameFeedback("这个新名字也超好听！😻");
      return;
    }
    playPetRenameFeedback("好喜欢这个名字呀！主人～🐾");
  });
  refs.accountPetNicknameInput.addEventListener("input", () => {
    updatePetRenameCopy();
  });
  refs.accountLogoutBtn.addEventListener("click", () => {
    if (!window.confirm(getDialogCopy().logoutConfirm)) return;
    state.settings.isLoggedIn = false;
    state.settings.isMember = false;
    state.settings.memberTier = "";
    persist();
    renderSettings();
    renderAccountOverlay();
    closeAccountOverlay();
    showToast(getToastCopy().logoutSuccess);
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
    }
    persist();
    updatePetVisibility();
    renderSettings();
  });

  const handleWeatherCompanionToggle = async (nextChecked) => {
    if (!nextChecked) {
      state.settings.weatherCompanionEnabled = false;
      persist();
      stopWeatherAutoRefresh();
      showToast(getToastCopy().weatherOff);
      renderSettings();
      return;
    }
    if (isRequestingWeatherPermission) {
      renderSettings();
      return;
    }
    // 先回到关闭态，避免用户关闭系统弹窗后开关卡在开启状态
    state.settings.weatherCompanionEnabled = false;
    persist();
    renderSettings();
    isRequestingWeatherPermission = true;
    const granted = await requestWeatherPermissionFlow();
    isRequestingWeatherPermission = false;
    if (!granted) {
      state.settings.weatherCompanionEnabled = false;
      persist();
      showToast(getToastCopy().weatherDenied);
      renderSettings();
      return;
    }
    state.settings.weatherCompanionEnabled = true;
    persist();
    startWeatherAutoRefresh();
    showToast(getToastCopy().weatherOn);
    renderSettings();
  };

  refs.weatherCompanionSwitch.addEventListener("change", async (e) => {
    await handleWeatherCompanionToggle(Boolean(e.target.checked));
  });
  refs.weatherNeutralSwitch.addEventListener("change", async (e) => {
    await handleWeatherCompanionToggle(Boolean(e.target.checked));
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
  updateDebugHUD("init-end");
  if (state.settings.weatherCompanionEnabled) {
    startWeatherAutoRefresh();
  }
  trackAnalytics("app_open", { item_count: state.items.length });
  updatePetVisibility();
  setTimeout(showPetFirstGuideOnce, 360);
  if (!localStorage.getItem(GUIDE_KEY)) {
    openGuide();
  }
  watchOverlayChanges();
  window.__qingzhangRuntime = {
    getUIState: () => ({ ...uiRuntimeState, currentTab }),
    getRuntimeErrors: () => {
      try {
        return JSON.parse(localStorage.getItem(ERROR_LOG_KEY) || "[]");
      } catch {
        return [];
      }
    },
    getAnalyticsEvents: readAnalyticsEvents,
    getAnalyticsSummary,
    trackAnalytics,
    getMemberNudgePolicy,
    setMemberNudgePolicy,
    setMemberNudgeMode: (mode) => setMemberNudgePolicy({ mode }),
    resolveDefaultNudgeModeByEnv,
    ensureMemberNudgePolicyForEnv,
    getMemberNudgeState,
    resetMemberNudgeState: () => setMemberNudgeState({ lastShownAt: 0, dailyDayKey: "", dailyCount: 0, sceneCooldownUntil: {} }),
    runStabilitySmokeChecks,
  };
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
