<p align="center">
  <img src="Resources/AppIcon.png" width="88" alt="EnvLatch 应用图标">
</p>

<h1 align="center">EnvLatch — 所有本地 Agent 共用一个 macOS 钥匙串</h1>

<p align="center">
  API Key 只保存一次。启动任何本地 Agent、SDK、脚本、测试或后端时，只注入它真正需要的 Key。
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.zh-CN.md"><strong>简体中文</strong></a>
</p>

<p align="center">
  <a href="https://github.com/Raylinkh/envlatch/releases"><img alt="Release" src="https://img.shields.io/github/v/release/Raylinkh/envlatch?include_prereleases&amp;style=flat-square&amp;color=725CFF"></a>
  <a href="https://github.com/Raylinkh/envlatch/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/Raylinkh/envlatch/ci.yml?branch=main&amp;style=flat-square&amp;label=CI"></a>
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-111111?style=flat-square&amp;logo=apple">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?style=flat-square&amp;logo=swift&amp;logoColor=white">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/github/license/Raylinkh/envlatch?style=flat-square"></a>
  <a href="https://github.com/Raylinkh/envlatch/releases"><img alt="Release downloads" src="https://img.shields.io/github/downloads/Raylinkh/envlatch/total?style=flat-square&amp;label=downloads"></a>
</p>

![EnvLatch 用一个 macOS 钥匙串替代分散在多个项目中的 .env 文件](docs/assets/marketing/envlatch-hero.png)

```sh
envlatch run --using ANTHROPIC_API_KEY -- claude
envlatch run --using GITHUB_TOKEN -- gh auth status
envlatch run --using OPENAI_API_KEY --using GITHUB_TOKEN -- npm test
envlatch run --using "Backend" -- npm test
```

EnvLatch 启动后的程序收到的是普通环境变量，所以现有代码仍然像读取 `.env` 一样工作。不需要
EnvLatch SDK、不需要 Provider 专用命令、不需要代理，也不需要修改业务代码。

## 为什么用 EnvLatch

- **所有 Provider 和工具共用一条命令。** 直接选择已保存的 Key，或选择可选的 Key
  Group；EnvLatch 不把你锁进某个 Provider。
- **需要多个 Key，也不用全量暴露。** 临时使用时重复 `--using`；经常复用时，把同一组
  Key 名称保存成 Key Group。未选择的 EnvLatch Key 不会从钥匙串读取。
- **兼容自定义 Endpoint。** 每个 Key 都可以映射到 Anthropic、OpenAI 或 Gemini 客户端
  期望的环境变量和 Base URL。
- **Agent 能使用，但看不到值。** 安装时附带的 Skill 会教任何 Agent 或 Host 查看非敏感
  Key 名称，并包装它原本要运行的命令。
- **原生、本地。** 值保存在 macOS 默认钥匙串的非同步项目中；没有服务器、账号、同步层或
  自制加密算法。

## 从源码安装

要求：macOS 13 或更新版本，以及 Xcode 16 或 Swift 6 工具链。

```sh
git clone https://github.com/Raylinkh/envlatch.git
cd envlatch
./scripts/install.sh
open "$HOME/Applications/EnvLatch.app"
```

安装脚本会：

- 构建 `EnvLatch.app` 并安装到 `~/Applications`；
- 创建 `~/.local/bin/envlatch`，指向 App 内的可执行文件；
- 把唯一的 Skill 安装到 `~/.agents/skills/envlatch`；
- 为 Codex、Claude Code 和 Gemini CLI 添加发现链接。

这些 Agent 链接只是方便发现，并不是白名单。旧的 EnvLatch 或 AgentKeyring 安装路径会先被
移动到带时间戳的备份。

源码构建默认使用 ad-hoc 签名，适合本机使用；重新构建后，macOS 可能再次要求授权读取已有的
钥匙串项目。可信二进制边界见[二进制发布](#二进制发布)。

## 快速开始

1. 打开 EnvLatch，选择 **Add Key**。
2. 保存一个像环境变量的名称，例如 `OPENAI_API_KEY`、`ANTHROPIC_API_KEY`、
   `GITHUB_TOKEN` 或 `AWS_SECRET_ACCESS_KEY`。
3. 如果客户端通过兼容 API 访问自定义 Endpoint，启用 **Endpoint profile**，设置
   Contract、Base URL 和目标凭证环境变量。
4. 直接使用已保存的 Key 名称启动原命令：

```sh
envlatch run --using OPENAI_API_KEY -- python3 server.py
```

5. 一条命令临时需要多个 Key 时，对每个已保存的 Key 名称重复 `--using`：

```sh
envlatch run \
  --using OPENAI_API_KEY \
  --using GITHUB_TOKEN \
  -- python3 server.py
```

6. 如果这个组合会反复使用，可以在 GUI 或 CLI 中保存只包含名称的 Key Group，再单独
   选择这个 Group：

```sh
envlatch groups create "Backend" \
  --using OPENAI_API_KEY \
  --using GITHUB_TOKEN
envlatch run --using "Backend" -- python3 server.py
```

`groups create` 不读取任何值，也不会覆盖已有 Group。Python、Node、Swift、Shell 及其
SDK 都照常读取环境变量：

```python
import os

openai_key = os.environ["OPENAI_API_KEY"]
github_token = os.environ["GITHUB_TOKEN"]
```

EnvLatch 使用 `execve` 把自己替换成目标程序，不会调用 Shell，也不会解释命令参数。

## Endpoint 元数据

Endpoint 元数据属于某个已保存的 Key，但永远不包含它的值。它可以记录：

- 显示名称；
- API Contract（Anthropic、OpenAI Chat Completions、OpenAI Responses 或 Gemini）；
- HTTPS Base URL；只有本机 Loopback 开发环境允许 HTTP；
- 目标客户端期望的凭证环境变量名。

例如，Key 本身可以继续叫 `MINIMAX_API_KEY`，Anthropic 兼容客户端则会收到同一个值的
`ANTHROPIC_AUTH_TOKEN`，以及配置好的 `ANTHROPIC_BASE_URL`。直接选择这个 Key、在一次
命令中重复选择多个 Key，或通过一个可选 Key Group 启动，都会得到这些绑定。

EnvLatch 会在读取任何值之前验证完整选择。缺失或重复 Key、在重复选择中混入 Group、两个
来源映射到同一个凭证变量，或 Contract 配置冲突时，它会直接拒绝启动，而不是采用“最后一个
覆盖前一个”的结果。

## Agent 和 Host 设置

Pairing 是可选的一次性设置状态，不是授权。任何 Agent 或 Host 都能提供自己的显示名称：

```sh
envlatch pair "My build agent"
envlatch doctor
envlatch help
envlatch groups
envlatch groups create "Backend" --using OPENAI_API_KEY --using GITHUB_TOKEN
```

GUI 会显示可复制的设置 Prompt，包含这些命令和最小权限规则。已安装的 Skill 会直接使用一个
Key 名称；临时多 Key 命令会重复 `--using`；需要复用时，则只用已保存的 Key 名称创建
Group。它绝不能悄悄回退到全量模式。

下面这些安全检查命令不会读取 Secret 值：

```sh
envlatch list
envlatch groups
envlatch doctor
envlatch version
envlatch help
```

`envlatch run -- <command>` 是显式兼容模式，会把所有已保存的 Key 暴露给目标进程。优先使用
`run --using`。

## 安全边界

EnvLatch 减少 API Key 意外进入仓库、`.env`、Shell Profile、终端历史、命令参数和自身日志
的机会。它刻意不提供 Reveal、剪贴板、Export、`eval` 或 `.env` 导出命令。

环境变量注入不等于 Secret 隔离。启动后的进程及其子进程能读取这次选择的所有变量，崩溃或
调试工具也可能暴露进程内存。EnvLatch 不会沙箱隔离恶意 Agent 或依赖；请使用有权限范围和
消费上限的 Key。

EnvLatch 保留调用者已有的环境变量。它不会读取未选择的 EnvLatch 钥匙串项目，但也不会清理
父进程已经导出的凭证。如果父环境也在威胁范围内，请从干净环境启动。

凭证名称必须是大写 POSIX 环境变量名，并使用受支持的凭证后缀。以 `DYLD_` 或 `LD_` 开头的
Loader 控制变量会被拒绝。EnvLatch 会先完全解析并验证可执行文件和符号链接，再从钥匙串读取值。

EnvLatch 改名后刻意保留内部钥匙串 Service `dev.agentkeyring.secrets` 和 Application
Support 目录 `AgentKeyring`，以便原有值继续留在同一个存储中，而不是迁移时复制一份。完整
边界和安全报告方式见 [SECURITY.md](SECURITY.md)。

## 开发

```sh
swift test --no-parallel
./scripts/build-app.sh
dist/EnvLatch.app/Contents/MacOS/EnvLatch --version
```

产品行为和发布验收契约在 [SPEC.md](SPEC.md)，当前证据及限制在
[VERIFICATION.md](VERIFICATION.md)。

GitHub Actions 会运行测试、校验脚本和 Bundle 元数据、构建 App，并验证结构性代码签名。

## 二进制发布

### 未签名预览版

GitHub `v0.2.0` Prerelease 包含明确标注的 ad-hoc 签名 arm64 DMG 和相邻的 SHA-256
Checksum。它是方便测试的构建，不是 Apple 验证的发行版。Gatekeeper 会要求在
**隐私与安全性 → 仍要打开** 中允许 Installer，也可能再次要求允许 App。

下载两个 Release Asset 后先验证：

```sh
shasum -a 256 -c EnvLatch-0.2.0-macos-arm64-unsigned.dmg.sha256
```

DMG 内的 `Install EnvLatch.command` 会事务式安装 App、CLI 和共享 Skill。只有当文件来自
EnvLatch 官方 Release 且 Checksum 通过时，才使用“仍要打开”。

### 已公证发行版

在完成 Developer ID 签名、Apple 公证、Staple，并通过 Gatekeeper 评估前，项目不会宣称有
“无摩擦”的可信二进制。具备这些凭证的维护者可以运行：

```sh
ENVLATCH_CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)" \
ENVLATCH_NOTARY_PROFILE="envlatch-notary" \
./scripts/package-release.sh
```

脚本会在 `dist/` 下生成已公证的 Zip 和 SHA-256 Checksum。在该证据存在前，未签名 DMG 和
源码安装仍是预览分发路径。

## License

[MIT](LICENSE)
