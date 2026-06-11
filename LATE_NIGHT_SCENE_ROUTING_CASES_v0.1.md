# 凌晨场景误判 Case 表 v0.1

更新时间：2026-06-11

范围：iOS 记账页场景包、`NarrativeCopyResolver`、旧记录 `displayEmotionTag` 降级。本文是回归护栏，不是新增产品功能。

## 1. 目标

凌晨记录最容易被误贴成“旅行 / 旅途 / 出发”。产品上宁可普通，也不要把一笔夜宵、通勤、娱乐写成旅游。

判断原则：

- 旅行文案必须有明确旅行证据。
- 没有旅行证据时，凌晨优先落到餐饮、通勤、居家、社交等普通生活场景。
- `出发`、`车站`、`门票` 单独出现不作为旅行证据。
- 旧数据里已经生成的旅行感 `emotionTag`，如果当前类目不是住宿且标题没有明确旅行证据，展示时降级为默认 tag。

## 2. 旅行证据

强证据，允许进入 travel：

```text
旅行、旅途、景区、景点、行程、酒店、民宿、住宿、机票、高铁、机场、返程、摆渡
```

弱词，不单独触发 travel：

```text
出发、车站、门票、路上、远一点、去下一站
```

说明：

- `门票` 可能是电影、演出、展览。
- `车站` 可能是通勤、打车、地铁接驳。
- `出发` 在通勤和早晨文案里太常见，不能作为旅行依据。

## 3. 必过 Case

| ID | 时间 | 类目 | 金额 | 标题/备注 | 期望场景包 | 不应出现 | 理由 |
| --- | --- | --- | ---: | --- | --- | --- | --- |
| LN-01 | 01:20 | 餐饮 | 28 | 加班后吃点热乎的 | food / nightSnack | travel、旅途、行程 | 明确夜宵语境 |
| LN-02 | 02:10 | 其他 | 18 | 空 | food | travel | 凌晨小额其他更像夜宵/临时日常 |
| LN-03 | 03:05 | 其他 | 68 | 空 | home | travel | 无旅行证据，不因金额进入旅行 |
| LN-04 | 00:30 | 娱乐 | 54 | 电影票 | social 或 entertainment fallback | travel、景区、旅途 | `票` 不等于旅行门票 |
| LN-05 | 23:40 | 交通 | 16 | 打车到地铁站接驳 | commute | travel | `车站/下一站` 不等于旅行 |
| LN-06 | 07:40 | 交通 | 4 | 刷卡进站，到站 | commute | travel | 早班通勤，不是旅行 |
| LN-07 | 01:10 | 住宿 | 320 | 今晚住在这里 | travel / lodging | 无 | 住宿类目本身是强证据 |
| LN-08 | 02:20 | 其他 | 120 | 酒店押金 | travel | 无 | 标题含酒店 |
| LN-09 | 05:50 | 交通 | 86 | 去机场 | travel | 无 | 标题含机场 |
| LN-10 | 04:30 | 交通 | 76 | 高铁改签 | travel | 无 | 标题含高铁 |
| LN-11 | 01:00 | 其他 | 45 | 出发前买瓶水 | food / home | travel | 只有出发，不够旅行 |
| LN-12 | 02:00 | 娱乐 | 120 | 展馆门票 | social / entertainment fallback | travel | 只有门票，不够旅行 |

## 4. 旧记录展示 Case

| ID | 类目 | 标题 | 已存 emotionTag | 展示期望 |
| --- | --- | --- | --- | --- |
| OLD-01 | 餐饮 | 加班后吃点热乎的 | 旅途中的轻量补给 | 降级为餐饮默认 tag |
| OLD-02 | 其他 | 临时花了一笔 | 行程里的一笔小开销 | 降级为其他默认 tag |
| OLD-03 | 住宿 | 短住一晚 | 途中连住两晚 | 保留 |
| OLD-04 | 交通 | 去机场 | 机场路上一笔 | 保留 |

## 5. 代码落点

- `NativeDemoApp/Views/RecordView.swift`
  - `guessScenePackId()`
  - `containsTravelKeyword(_:)`
- `NativeDemoApp/Services/NarrativeCopyResolver.swift`
  - `scenePack(for:)`
  - `containsTravelKeyword(_:)`
- `NativeDemoApp/Models/HomeItem.swift`
  - `displayEmotionTag`
  - `containsTravelKeyword(_:)`
- `NativeDemoApp/Services/ScenePackCopyPool.swift`
  - `contextualNotes(...)`

## 6. 回归验收

- 凌晨普通消费连续换句 10 次，不出现旅行、旅途、行程、景区、出发。
- 明确酒店/机场/高铁/机票仍能进入 travel。
- 旧记录中非住宿、无旅行证据的旅行感 tag 不再展示。
- 没有真机条件时，至少对照本表手工检查代码分支。

