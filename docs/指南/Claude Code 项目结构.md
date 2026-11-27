# Claude Code 项目结构（2026-11）

> 类型：指南 | 状态：有效 | 核对：2026-11-27
> 何时读：改 `.claude/` 配置（CLAUDE.md、rules、settings、hooks、skills、agents、workflows）、排查 Claude Code 加载/权限行为
> 关键词：Claude Code 项目结构 CLAUDE.md AGENTS.md settings.json mcp hooks skills agents workflows agent-memory rules 权限 优先级 2.1.329 Code Mode
> 代码：—
> 相关：`指南/代码检查.md`；本仓库约定以根 `CLAUDE.md` 与 `.claude/rules/` 为准

## 1. 基线与文档抓取

- 本机与官方 changelog 基线：`2.1.329`（2026-11-20）。标注：✅ 官方核对 · ⚠️ 仅摘要未逐页验证 · 🖥️ 本机 CLI 实测。
- 本环境 WebFetch 不可用，用 Bash `curl` 直连：`curl -sSL https://code.claude.com/docs/en/hooks.md`；changelog 经 GitHub API `contents/CHANGELOG.md` 取 SHA 后拉 `git/blobs/$SHA`（`Accept: application/vnd.github.raw`）。

## 2. 配置文件与加载规则

| 路径 | 作用域 / 进 git | 加载时机与核心约束 |
|---|---|---|
| `CLAUDE.md` / `CLAUDE.local.md` | 团队 / 个人(ignore) | ✅ 根→cwd 逐层合并，子目录工作时按需加载；`@path` 最多 4 层、单导入 ≤4 MiB；建议 ≤200 行；子代理可用 `omitClaudeMd` 跳过（Explore/Plan 默认跳过） |
| `AGENTS.md` | 团队 | ✅ 仅当 cwd 及父目录均无 CLAUDE.md 时生效（`/config → Project instructions`，⚠️ Bedrock/Vertex/Foundry 不支持） |
| `.claude/rules/*.md` | 团队 | ✅ 递归发现；无 `paths` 启动加载，带 `paths` 仅命中 Read/Write/Edit(2.1.288+)/Bash 查看(2.1.293+) 时加载；支持符号链接 |
| `.claude/settings(.local).json` | 团队 / 个人(ignore) | ✅ 优先级 **managed > CLI > local > project > user**；数组拼接去重、标量覆盖；⚠️ 信任框仅卡 `allow`/`additionalDirectories`/`extraKnownMarketplaces`，`deny`/`ask` 立即生效 |
| `.mcp.json` | 团队 | ✅ 优先级 **local > project > user**；支持 `stdio`/`http`/`ws`（⚠️ `ws` 仅 `.mcp.json`/`mcp add-json`），`sse` 已弃用；支持 `${VAR:-default}` 与 `/mcp` OAuth |
| `~/.claude/` | 用户级 | 🖥️ 存用户 settings/skills/agents/plugins/projects/sessions/workflows 及 `projects/<proj>/memory/MEMORY.md` |

## 3. 扩展点速查

| 扩展目录 | 机制与硬限制 |
|---|---|
| `.claude/skills/<name>/SKILL.md` | ✅ 目录名即 `/命令`；启动只载 `name + description`，正文按需；旧 `.claude/commands/` 仍可用但同名 skill 优先；⚠️ 支持 `${CLAUDE_SKILL_DIR}`、`/reload-skills`、`--add-dir`（`additionalDirectories` 不加载）。本仓固定流程：改完 → `check.sh --all` → review → spec 退出 → commit → 交接 |
| `.claude/agents/<name>.md` | ✅ 独立上下文；内置 Explore/Plan/general-purpose（🖥️ 另有 `claude-code-guide`/`statusline-setup`/`fork`）；全部自定义 description 合计 >15k tokens 启动告警；⚠️ 默认后台、并发约 20、嵌套 ≤3 层 |
| `.claude/hooks/<script>` | ✅ 33 个事件 × 5 种类型（`command`/`http`/`mcp_tool`/`prompt`/`agent`；`SessionStart` 仅 `command`/`mcp_tool`）；退出码 2 或 `onFailure: "block"` 阻断；默认超时 command/http/mcp_tool 600s、prompt 30s、agent 60s |
| `.claude/workflows/<name>.js` | ✅ `agent()`/`parallel()`/`pipeline()` 编排；并发默认 16（`CLAUDE_CODE_WORKFLOW_MAX_CONCURRENT_AGENTS` 可调 1–256）；共享首代理缓存的扇出最多延迟 5s；唯一内置 `/deep-research` |
| `.claude/agent-memory/<agent>/MEMORY.md` | ✅ 设 `memory: project` 启用；每次加载前 **200 行或 25KB**，超限写入报错要求重写索引 |

## 4. CLI 能力与速查

| 能力 | 入口 / 说明 | 依据 |
|---|---|---|
| 后台会话 / 代理 | `claude --bg`、`agents`、`attach`、`logs`、`respawn`、`stop` | 🖥️ |
| 云端审查 / 权限 | `claude ultrareview`；`claude auto-mode` 查看/重置权限模式 | 🖥️ / ⚠️ |
| Code Mode / 会话任务 | 代码编排工具调用（2.1.329 可同开 OTel）；`/tasks` 汇总定时任务、`/loop`、forks | ✅ |
| 配置工具 / 实验能力 | `claude import/purge/gateway/install`；agent teams / ultracode / `mods/` | 🖥️ / ⚠️ |
