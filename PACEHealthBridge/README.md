# PACE HealthKit Bridge (iOS 17+)

这是 **PACE 原生 iPhone 容器 + HealthKit 只读桥接** 的源代码。
目标：Apple Watch 上点「传统力量训练」与「室内步行」开始/结束；iPhone 上启动桥接 App 并点「同步健康数据」，即可在内置 PACE 的「Watch 分析」查看运动时间、心率采样及每日步数。

## 状态与限制

- ✅ 代码已完成：SwiftUI、HealthKit 查询、WKWebView 安全消息、PACE 网页接收和分析。
- ✅ PACE 网页已经部署： https://zfcheng.github.io/zfczoe.github.io/pace/
- ⚠️ 目前尚未在真实 iPhone 上用 Xcode 编译签名、安装及 HealthKit 实机验证。
- ⚠️ 浏览器 PWA 与原生 WKWebView 的本地存储**互不共享**。原有 Safari PACE 训练数据不会自动出现在原生桥接 App 中；可先在原 PACE 的「设置与数据」导出备份，再在原生 App 内导入备份（请注意导入会覆盖 App 当前记录）。
- ⚠️ App 加载 GitHub Pages 的 PACE 前端代码；不要将页面替换为不可信站点，也不要在 GitHub 中提交个人健康导出文件。
- **没有云端健康数据库**。本工程读取的健康数据被交给内置 WKWebView，保存在该应用的本地网站存储中，不会由桥接代码主动上传第三方服务器。
- **不支持后台自动同步、跨设备同步、WatchOS 原生训练识别、App Store 上架**；这些需要后续开发。

## Mac 上安装到 iPhone

需要 Mac、Xcode 16 或更新版本、iPhone（iOS 17+）以及 Apple 开发团队签名配置。

```bash
git clone https://github.com/zfcheng/zfczoe.github.io.git
cd zfczoe.github.io
git switch pace-healthkit-bridge
cd PACEHealthBridge
brew install xcodegen
xcodegen generate
open PACEHealthBridge.xcodeproj
```

在 Xcode 中：
1. 选择 Target **PACEHealthBridge** → **Signing & Capabilities**，选择你自己的 Team。若签名冲突，将 Bundle Identifier 改为你自己的唯一标识。
2. 确认 **HealthKit** Capability 已存在，并启用适用的签名权限。项目中提供了 HealthKit entitlement 和 NSHealthShareUsageDescription。
3. 用数据线或无线配对 iPhone，选择这台真实设备（不要用模拟器验证 HealthKit）。
4. 点击 **Run** 安装 App。若 Xcode 签名提示该账号无法使用 HealthKit，请使用具备 HealthKit capability 的 Apple 开发团队；部分签名方案需付费开发者会员。
5. iPhone 上首次点「同步健康数据」，在系统弹窗中允许读取 **体能训练、心率、步数**。
6. Apple Watch 完成训练，确认已经同步到 iPhone 健康 App，再回到桥接 App 点一次「同步健康数据」。

## 数据结构

JS 接收 `window.PACEBridge.receiveBase64(base64)`，Base64 中是 JSON：

```json
{
  "schemaVersion": 1,
  "source": "iOS HealthKit (read-only)",
  "generatedAt": "2026-11-11T00:00:00Z",
  "workouts": [{"id":"opaque-id","type":"walking","start":"2026-11-11T09:10:00Z","end":"2026-11-11T09:30:00Z","durationMinutes":20,"activeKcal":70}],
  "heartRate": [{"ts":"2026-11-11T09:15:00Z","bpm":113}],
  "steps": [{"date":"2026-11-11","count":6500}]
}
```

上述 JSON 只是格式示例，数字不代表用户真实数据。没有对应心率采样时显示「暂无心率采样」，不会伪造数值。

## 安全约束

- 只读取 `workout` / `heartRate` / `stepCount`，不读病历、GPS 或联系人。
- 只从指定的 PACE HTTPS 域名路径接收桥接指令；第三方网站在系统 Safari 中打开。
- 数据通过 JS 原生接口直接注入 WKWebView，没有放在 URL 参数中，也没有发送到后端 API。
- 任何需要分享数据到云端的新功能，都必须单独取得明确同意，并增加权限、身份验证、传输加密和隐私说明。

## 后续可选能力

- 心率恢复、静息心率和每周心肺耐力趋势
- 本地 HealthKit 锚定增量同步与自动化
- TestFlight 分发（需要具备 Apple Developer Program 和签名/发布权限）
