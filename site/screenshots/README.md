# 官网截图素材

将真机截图导出为 PNG，按下列文件名放入本目录。官网轮播按此顺序显示。

当前 12 张来自 `E:\叙账截图` 的 1290×2796 原图，已去掉系统状态栏和 Dynamic Island，保留默认手账主题的真实界面。同源文件也在 `output/app-store-screenshots-v5/`，可直接用于后续 App Store 6.7 英寸预览；6.5 英寸副本在 `upload-ready-6.5-inch/`。

| 文件名 | 对应画面 | 尺寸 |
|--------|----------|------|
| `01-home-empty.png` | 今日 · 空态 | 1290×2796（iPhone 6.7 英寸） |
| `02-record-amount.png` | 记下 · 先记金额 | 同上 |
| `03-record-preview.png` | 记下 · 确认后放进账本 | 同上 |
| `04-home-first.png` | 今日 · 第一笔记录 | 同上 |
| `05-home-today.png` | 今日 · 多笔痕迹 | 同上 |
| `06-scene-packs.png` | 场景包 · 换个角度 | 同上 |
| `07-trace-week.png` | 痕迹 · 本周已载入 | 同上 |
| `08-review.png` | 复盘 | 同上 |
| `09-clues.png` | 线索 | 同上 |
| `10-ai-console.png` | AI 指令台 | 同上 |
| `11-me.png` | 我的 | 同上 |
| `12-appearance.png` | 外观 · 默认手账 | 同上 |

重新生成：`python scripts/make_site_carousel_screenshots.py`

源目录里未进入轮播的原图保持不动，不复制进本目录。
