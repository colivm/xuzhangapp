const STORAGE_KEY = "qingzhang_preview_v1";
const GUIDE_KEY = "qingzhang_preview_guide_done_v1";
const categories = [
  { value: "餐饮", label: "吃饭", icon: "🍽️" },
  { value: "购物", label: "买东西", icon: "🛒" },
  { value: "交通", label: "出行", icon: "🚇" },
  { value: "娱乐", label: "玩", icon: "🎮" },
  { value: "日用", label: "生活", icon: "🧴" },
  { value: "其他", label: "随便", icon: "⚪" },
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
const INSIGHT_BTN_IDLE_TEXT = "换一条更适合我的建议";
const INSIGHT_BTN_LOADING_TEXT = "正在为你换一条…";
const CATEGORY_AI_ENDPOINT = "http://localhost:8787/v1/category/recommend";
const pageTitles = {
  home: "首页",
  record: "记账",
  stats: "统计",
  insight: "AI 复盘",
  settings: "设置",
};

const defaultState = {
  settings: {
    displayName: "轻账用户",
    appearance: "system",
    syncEnabled: false,
    remoteAIEnabled: false,
  },
  recordMode: "manual",
  period: "week",
  items: [],
  insights: [],
  isGeneratingInsight: false,
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
  homeTodayEmpty: document.getElementById("homeTodayEmpty"),
  homeInsightSummary: document.getElementById("homeInsightSummary"),
  homeInsightHint: document.getElementById("homeInsightHint"),
  dailyNudge: document.getElementById("dailyNudge"),
  modeButtons: [...document.querySelectorAll(".mode-btn")],
  manualForm: document.getElementById("manualForm"),
  ocrForm: document.getElementById("ocrForm"),
  amountInput: document.getElementById("amountInput"),
  amountAssist: document.getElementById("amountAssist"),
  categoryField: document.getElementById("categoryField"),
  titleInput: document.getElementById("titleInput"),
  noteSuggestions: document.getElementById("noteSuggestions"),
  noteField: document.getElementById("noteField"),
  networkHint: document.getElementById("networkHint"),
  categoryOptions: document.getElementById("categoryOptions"),
  recordDateInput: document.getElementById("recordDateInput"),
  dateHint: document.getElementById("dateHint"),
  localPrivacyHint: document.getElementById("localPrivacyHint"),
  editDateBtn: document.getElementById("editDateBtn"),
  saveRecordBtn: document.getElementById("saveRecordBtn"),
  ocrPrefillBtn: document.getElementById("ocrPrefillBtn"),
  periodButtons: [...document.querySelectorAll(".period-btn")],
  categoryStats: document.getElementById("categoryStats"),
  categoryStatsEmpty: document.getElementById("categoryStatsEmpty"),
  insightSummary: document.getElementById("insightSummary"),
  insightAction: document.getElementById("insightAction"),
  insightEncourage: document.getElementById("insightEncourage"),
  insightHistory: document.getElementById("insightHistory"),
  insightHistoryEmpty: document.getElementById("insightHistoryEmpty"),
  generateInsightBtn: document.getElementById("generateInsightBtn"),
  insightLoading: document.getElementById("insightLoading"),
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
  Object.keys(refs.pages).forEach((key) => refs.pages[key].classList.toggle("active", key === tab));
  refs.tabs.forEach((btn) => btn.classList.toggle("active", btn.dataset.tab === tab));
  refs.pageTitle.textContent = pageTitles[tab];
  if (tab === "record") {
    setTimeout(() => {
      refs.amountInput?.focus();
    }, 40);
  }
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

function formatCNY(value) {
  return value.toLocaleString("zh-CN", { style: "currency", currency: "CNY" });
}

function isAmountReady() {
  return Number(refs.amountInput?.value) >= 0.01;
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
  const amount = Number(refs.amountInput?.value);
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

  const amount = Number(refs.amountInput?.value);
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
  if (!isAmountReady()) {
    refs.categoryOptions.innerHTML = "";
    return;
  }
  const recommended = localRecommendedCategory();
  const shortlist = likelyCategoryValues(Number(refs.amountInput.value), recommended);
  // Ensure there is always one default selected category in the visible shortlist.
  if (!selectedCategory || !shortlist.includes(selectedCategory)) {
    selectedCategory = recommended && shortlist.includes(recommended) ? recommended : shortlist[0];
  }
  refs.categoryOptions.innerHTML = "";
  categories
    .filter((item) => shortlist.includes(item.value))
    .forEach((item) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "category-chip";
    if (item.value === selectedCategory) button.classList.add("active");
    if (item.value === recommended) button.classList.add("recommended");
    if (item.value === pulseCategoryValue) button.classList.add("pulse-recommend");
    button.textContent = `${item.icon} ${item.label}`;
    button.addEventListener("click", () => {
      selectCategory(item.value);
      button.classList.remove("just-selected");
      requestAnimationFrame(() => {
        button.classList.add("just-selected");
      });
    });
    refs.categoryOptions.appendChild(button);
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
  refs.homeTodayEmpty.style.display = recent.length ? "none" : "block";
  recent.forEach((item) => {
    const li = document.createElement("li");
    li.innerHTML = `
      <div class="item-title-row">
        <span>${item.title}</span>
        <span>${formatCNY(item.amount)}</span>
      </div>
      <p class="muted">${item.category} · ${new Date(item.createdAt).toLocaleString()}</p>
    `;
    refs.homeTodayList.appendChild(li);
  });

  const todayInsight = state.insights.find((x) => x.dayKey === todayKey);
  refs.homeInsightSummary.textContent = todayInsight
    ? `${todayInsight.summary} ${todayInsight.action}`
    : "今天还没有复盘，去 AI 复盘页生成一条吧。";

  const targetCount = 5;
  const remaining = Math.max(0, targetCount - todayItems.length);
  refs.homeInsightHint.textContent =
    remaining > 0
      ? `今天的账单已经记了 ${todayItems.length} 笔，还差 ${remaining} 笔就能生成完整的 AI 复盘啦。`
      : `今天的账单已经记了 ${todayItems.length} 笔，AI 复盘已经很完整啦。`;

  refs.dailyNudge.textContent = todayItems.length
    ? "今天已经有记录啦，花 10 秒再补一笔会更完整。"
    : "今天还没记账哦，花 10 秒记一笔吧。";
}

function renderRecord() {
  const amountReady = isAmountReady();
  refs.modeButtons.forEach((btn) => btn.classList.toggle("active", btn.dataset.mode === state.recordMode));
  refs.manualForm.classList.toggle("hidden", state.recordMode !== "manual");
  refs.ocrForm.classList.toggle("hidden", state.recordMode !== "ocr");
  if (state.recordMode !== "manual") return;

  const wasDisabled = refs.saveRecordBtn.disabled;
  refs.categoryField.classList.toggle("hidden", !amountReady);
  refs.noteField.classList.toggle("hidden", !amountReady);
  refs.amountAssist.classList.toggle("hidden", amountReady);
  refs.networkHint.classList.toggle("hidden", !amountReady || !state.settings.remoteAIEnabled);
  refs.dateHint.classList.toggle("hidden", !amountReady);
  refs.localPrivacyHint.classList.toggle("hidden", !amountReady);
  refs.editDateBtn.classList.toggle("hidden", !amountReady);
  refs.saveRecordBtn.disabled = !amountReady;
  if (wasDisabled && amountReady) {
    refs.saveRecordBtn.classList.remove("save-ready");
    requestAnimationFrame(() => {
      refs.saveRecordBtn.classList.add("save-ready");
      setTimeout(() => refs.saveRecordBtn.classList.remove("save-ready"), 220);
    });
  }

  if (!amountReady) {
    refs.noteSuggestions.classList.add("hidden");
  }
  updateCategoryUI();
}

function renderStats() {
  refs.periodButtons.forEach((btn) => btn.classList.toggle("active", btn.dataset.period === state.period));
  const items = state.items.filter((x) => (state.period === "week" ? sameWeek(x.createdAt) : sameMonth(x.createdAt)));
  const total = items.reduce((sum, x) => sum + x.amount, 0);
  const grouped = {};
  items.forEach((item) => {
    grouped[item.category] = (grouped[item.category] || 0) + item.amount;
  });
  const rows = Object.entries(grouped).sort((a, b) => b[1] - a[1]);

  refs.categoryStats.innerHTML = "";
  refs.categoryStatsEmpty.style.display = rows.length ? "none" : "block";
  rows.forEach(([category, amount]) => {
    const li = document.createElement("li");
    const ratio = total ? Math.round((amount / total) * 100) : 0;
    li.innerHTML = `<div class="item-title-row"><span>${category}</span><span>${formatCNY(amount)}</span></div><p class="muted">${ratio}%</p>`;
    refs.categoryStats.appendChild(li);
  });
}

function renderInsight() {
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

  refs.insightLoading.classList.toggle("hidden", !state.isGeneratingInsight);
  refs.generateInsightBtn.disabled = state.isGeneratingInsight;
  refs.generateInsightBtn.textContent = state.isGeneratingInsight ? INSIGHT_BTN_LOADING_TEXT : INSIGHT_BTN_IDLE_TEXT;
  refs.generateInsightBtn.classList.toggle("generating", state.isGeneratingInsight);
}

function renderSettings() {
  refs.displayNameInput.value = state.settings.displayName;
  refs.syncSwitch.checked = state.settings.syncEnabled;
  refs.remoteAISwitch.checked = state.settings.remoteAIEnabled;
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
  updateCategoryUI();
  refs.amountInput.addEventListener("input", () => {
    renderRecord();
    scheduleCategoryRecommendation();
  });
  refs.amountInput.addEventListener("focus", () => {
    document.querySelector(".app-shell")?.classList.add("keyboard-active");
    setTimeout(() => {
      refs.amountInput.scrollIntoView({ behavior: "smooth", block: "center" });
    }, 120);
  });
  refs.amountInput.addEventListener("blur", () => {
    document.querySelector(".app-shell")?.classList.remove("keyboard-active");
  });
  refs.titleInput.addEventListener("input", () => {
    renderNoteSuggestions();
    scheduleCategoryRecommendation();
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
      state.recordMode = btn.dataset.mode;
      persist();
      renderRecord();
    })
  );

  refs.periodButtons.forEach((btn) =>
    btn.addEventListener("click", () => {
      state.period = btn.dataset.period;
      persist();
      renderStats();
    })
  );

  refs.saveRecordBtn.addEventListener("click", () => {
    const ok = addRecord({
      title: refs.titleInput.value.trim(),
      amount: Number(refs.amountInput.value),
      category: selectedCategory || "其他",
      source: "manual",
      occurredAt: refs.recordDateInput.value,
    });
    if (ok) {
      refs.titleInput.value = "";
      refs.amountInput.value = "";
      selectedCategory = topCategoryFromHistory();
      categoryLockedByUser = false;
      updateCategoryUI();
      refs.noteSuggestions.classList.add("hidden");
      refs.noteSuggestions.innerHTML = "";
      refs.recordDateInput.value = new Date().toISOString().slice(0, 10);
      showToast("手动记录已保存");
      switchTab("home");
    }
  });

  refs.ocrPrefillBtn.addEventListener("click", () => {
    const ok = addRecord({ title: "OCR识别账单", amount: 26.5, category: "餐饮", source: "ocr" });
    if (ok) {
      showToast("OCR 演示记录已保存");
      switchTab("home");
    }
  });

  refs.generateInsightBtn.addEventListener("click", generateTodayInsight);

  refs.displayNameInput.addEventListener("input", (e) => {
    state.settings.displayName = e.target.value.trim() || "轻账用户";
    persist();
    renderHome();
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
