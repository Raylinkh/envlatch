# EnvLatch v0.1.0 小红书发布包

状态：未发布，已被 v0.2.0 多 Key CLI 更新取代；不要直接发布这套旧文案。

## 图片顺序

1. `docs/assets/marketing/xiaohongshu/01-cover-before-after.png`
   - 封面：**不要再重复复制粘贴你的 API Key 了**
   - 用 `.env × 3 → 一个 Keychain` 的真实前后对比说明核心价值。
2. `docs/assets/marketing/xiaohongshu/02-real-product-and-commands.png`
   - 真实产品界面：公开截图使用虚构 Key 名称和配对状态。
   - Key、Endpoint、可选 Key Group 和 Agent Setup 都在同一界面。
   - 展示 Claude Code、GitHub CLI、Backend 共用同一条 provider-agnostic 命令。
3. `docs/assets/marketing/xiaohongshu/03-three-step-setup.png`
   - 三步设置：保存 Key、按名称选择、启动原命令。
   - 用真实 Add Key 界面、完整命令和现有 Python 代码证明不需要 SDK。
4. `docs/assets/marketing/xiaohongshu/04-security-boundary.png`
   - 清楚区分 EnvLatch 会做和不会做的事。
   - 明示环境变量注入不是沙箱，未签名预览版仍需要 Open Anyway。

## 建议标题

不要再复制粘贴你的 API Key 了：一个 macOS 钥匙串给所有 Agent 用

## 正文

我不想再在不同项目、Agent、脚本和后端之间复制 `.env` 了。

所以做了 EnvLatch：一个原生 macOS 小工具，把 API Key 保存到 Keychain，需要时再按 Key
名称注入到原命令的环境变量里。

使用方式只有三步：

1. 在 GUI 保存一次 Key；
2. 直接选择 Key 名称，需要多个时才建立 Key Group；
3. 在原命令前加：

```sh
envlatch run --using ANTHROPIC_API_KEY -- claude
```

Python、Node、Swift、Shell、Agent CLI 和本地 Backend 都不用改代码，也不需要 EnvLatch
SDK。自定义 Anthropic / OpenAI / Gemini 兼容 Endpoint 也能和 Key 一起配置。

它解决的是“不要把 Secret 到处复制”，不是把不可信进程变安全：启动后的程序仍然能读取你这次
选择的环境变量，所以仍建议使用有权限范围和消费上限的 Key。

项目已开源：

https://github.com/Raylinkh/envlatch

目前 `v0.1.0` 是明确标注的 arm64 未签名预览版。更稳妥的体验是从源码安装；下载 DMG 时请先
核对 SHA-256，并了解 Gatekeeper 会要求“仍要打开”。

## 标签

#AI工具 #开发者工具 #Mac软件 #APIKey #ClaudeCode #Codex #开源软件 #效率工具

## ImageGen 生产说明

模式：内置 ImageGen。

最终方向参考 Tabbie enhanced candidates 的证据优先构图：真实产品界面占主要画面，用一个结果
标题、前后对比和少量指向性说明，让价值与设置路径一眼可见。ImageGen 只生成低对比的安全传递
背景纹理；真实 GUI、命令、中文文字和信息结构均在本地确定性合成。

最终提示词摘要：

- README 背景纹理：深色 macOS 开发工具氛围；一个本地安全 Vault 连接多个终端；紫色与青色；
  右侧为产品截图保留安静空间；无文字、无品牌、无伪造 UI。
- 初始小红书问题场景：多个项目和终端之间重复搬运 Secret；深紫背景、珊瑚色风险提示；无文字。
- 初始小红书方案场景：单一 Keychain Vault 按需连接多个 Agent；强调本地、最小权限；无文字。
- 初始三步场景：保存、选择、运行的三阶段流程；深色工程工具美术方向；无文字。

初始装饰性候选没有进入发布包。最终成品只复用第一条提示词生成的低对比背景，前景全部来自安全
脱敏后的产品截图和确定性排版。
