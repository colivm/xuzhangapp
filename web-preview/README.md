# 序帐 Web 预览

这是 `序帐` 的网页镜像演示版（替代旧示例），用于在 Windows 快速预览完整核心页面：

- 首页
- 记账（手动 + OCR 演示）
- 统计（周 / 月）
- AI 复盘（每日建议）
- 设置（本地优先、外观、同步演示）

## 运行方式

任选其一：

1. 直接双击打开 `index.html`
2. 用本地静态服务器打开（推荐）

PowerShell 示例（如果安装了 Python）：

```powershell
cd D:\workspace\iosdemo\web-preview
python -m http.server 8080
```

然后访问：`http://localhost:8080`
