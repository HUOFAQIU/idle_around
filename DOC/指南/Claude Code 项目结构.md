# Claude Code 项目结构（2026-11）

> 类型：指南 | 状态：有效
> 何时读：改 `.claude/` 配置（CLAUDE.md、settings、hooks、skills、agents、workflows）、排查 Claude Code 的加载/权限行为
> 关键词：Claude Code 项目结构 CLAUDE.md AGENTS.md settings.json mcp hooks skills agents workflows agent-memory rules 权限 优先级 2.1.329 Code Mode
> 代码：—
> 相关：`指导文件.md`；本仓库自己的约定以根 `CLAUDE.md` 为准，不在此重复
> 核对：2026-11-21

## 1. 基线

- 本机版本：2.1.329（2026-11-20）；官方 changelog 最新条目同为 2.1.329。
- 标注：✅ 官方文档/changelog 原文核对 · ⚠️ 仅搜索摘要未逐页验证 · 🖥️ 本机 CLI 实测。
- 抓取方式：本环境 WebFetch 不可用（连 `example.com` 也失败），Bash 里 `curl` 可直连。

```bash
# 官方文档有 .md 纯文本版
curl -sSL https://code.claude.com/docs/en/hooks.md
# changelog：raw.githubusercontent 不通，走 GitHub API blobs
SHA=$(curl -sS https://api.github.com/repos/anthropics/claude-code/contents/CHANGELOG.md \
  | grep -oE '"sha": *"[a-f0-9]{40}"' | head -1 | grep -oE '[a-f0-9]{40}')
curl -sS -H "Accept: application/vnd.github.raw" \
  https://api.github.com/repos/anthropics/claude-code/git/blobs/$SHA
```

## 2. 目录树

```text
your-repo/
├── CLAUDE.md                 # 项目指令，每次会话加载
├── CLAUDE.local.md           # 私人笔记，gitignore
├── AGENTS.md                 # 无 CLAUDE.md 时的替代
├── .mcp.json                 # 团队共享 MCP 服务器
└── .claude/                  # 提交，与团队共享
    ├── settings.json         # permissions / env / model / hooks
    ├── settings.local.json   # 个人覆盖，gitignore
    ├── rules/                # 一文件一主题
    ├── skills/<name>/SKILL.md（+ 可选 scripts/）
    ├── agents/<name>.md
    ├── hooks/<script>
    ├── workflows/<name>.js
    └── agent-memory/<agent>/MEMORY.md
```

仓库之外：`~/.claude/`（用户级 settings、skills、agents、plugins、projects、sessions）、`~/.claude/workflows/`、`~/.claude/projects/<project>/memory/MEMORY.md` 🖥️

## 3. 指令加载

### 3.1 CLAUDE.md / AGENTS.md

- ✅ 启动时从根目录到当前目录**逐层合并**；子目录的 CLAUDE.md 等 Claude 在该处工作才加载。
- ✅ `CLAUDE.local.md` 是私人补充，应 gitignore。
- ✅ `@path` 导入最多 **4 层**；被导入文件超过 **4 MiB** 整份跳过。
- ✅ 官方建议单文件 **200 行以内**，超了占用上下文并降低遵循度。
- ✅ 无 CLAUDE.md 时改用 `AGENTS.md`；由 `/config → Project instructions` 控制。
- ⚠️ 生效条件：cwd 及其所有父目录都没有 CLAUDE.md / CLAUDE.local.md；Bedrock / Vertex / Foundry 不支持。
- ✅ 子代理可用 frontmatter `omitClaudeMd` 跳过这些文件；Explore / Plan 默认就不加载。

### 3.2 rules/

- ✅ 每个 `.md` 一个主题，递归发现。
- ✅ 无 frontmatter → 启动即加载；带路径规则 → 只在命中时加载。
- ⚠️ 触发面：Read 匹配文件、Write/Edit（2.1.288+）、Bash 查看文件（cat/head/grep，2.1.293+）；frontmatter 只认 `paths`。
- ✅ 可用符号链接共享一份 rules（外部目标需一次性授权）。

## 4. 配置与权限

### 4.1 settings.json

- ✅ 常用键：`permissions`（allow / ask / deny）、`env`、`model`、`hooks`。
- ✅ `settings.local.json` 为个人覆盖，不进 git。
- ✅ 优先级：**managed > CLI > local > project > user**。
- ✅ 合并：数组键（如 `permissions.allow`）拼接去重，标量后者覆盖。
- ⚠️ 工作区信任只卡 `allow`、`additionalDirectories`、`extraKnownMarketplaces`；`deny` / `ask` 立即生效。
- ⚠️ managed 层内部再分 `managed-settings.d/*.json`、`policyHelper`（remote > MDM > 文件 > 注册表）。
- ✅ 2.1.329：信任对话框标注文件夹的 hooks 声明来自哪里。

### 4.2 MCP（`.mcp.json`）

- ✅ 团队服务器写在 `mcpServers`；作用域优先级 **local > project > user**。
- ✅ 传输：`stdio`、`http`、`ws`；`sse` 已弃用。
- ⚠️ `ws` 是 Claude Code 私有扩展，`--transport` 不接受，只能写 `.mcp.json` 或用 `mcp add-json`；`sse` 有 HTTP→SSE 回退。
- ✅ 添加用 `claude mcp add --scope project`；支持 `${VAR}` 与 `${VAR:-default}`。
- ✅ 授权：`/mcp` 里走 OAuth；2.1.329 起服务器页有 Server message 行显示 JSON-RPC 错误。

## 5. 扩展点

### 5.1 skills/（commands 已并入）

- ✅ 每技能一个文件夹，内含 `SKILL.md`；文件夹名即命令名（`/deploy`）。
- ✅ 启动时上下文只有 **name + description**，正文按需加载。
- ✅ `.claude/commands/x.md` 是旧格式，继续可用；不支持 `name` / `paths`，同名时 skill 优先。
- ⚠️ 扩展 frontmatter：`allowed-tools / compatibility / license / metadata`；支持 `${CLAUDE_SKILL_DIR}`、`/reload-skills`。
- ⚠️ `--add-dir` 会加载该目录的 skills/commands/agents；`permissions.additionalDirectories` 只给文件权限，不加载。
- 项目内工作流顺序固定：改完 → `check.sh --all` → review（spec 状态「已实现」）→ spec 退出 → commit → 交接。review 遇到已删除的 spec 时从 git 历史读，不要跳过 Spec 轴。

### 5.2 agents/

- ✅ 每代理一个 `.md`，正文即系统提示词，独立上下文窗口。
- ✅ 支持 `tools / model / memory / isolation: worktree`；name 与 description 都应填写。
- ✅ 内置 Explore、Plan、general-purpose；Explore / Plan 启动不加载 CLAUDE.md 和 git 状态。
- 🖥️ 本机还可见 `claude-code-guide`、`statusline-setup`、`fork`（继承父上下文）。
- ✅ 所有自定义代理的 description 合计超 **15,000 tokens** 启动告警。
- ⚠️ 默认后台运行；并发约 20；嵌套最深 3 层；新增 frontmatter `disallowedTools / permissionMode / maxTurns / skills / mcpServers / hooks / effort / color`。

### 5.3 hooks/

- ✅ 配置在 settings.json 的 `"hooks"` 下，脚本放 `hooks/`；`/hooks` 可浏览。
- ✅ 生命周期事件共 **33 个**。
- ✅ 类型只有 5 种：**`command` / `http` / `mcp_tool` / `prompt` / `agent`**（没有 `stop`，Stop 是事件名；没有裸 `mcp`）。
- ✅ 退出码 2 阻断；也可 `onFailure: "block"`（2.1.295+，`mcp_tool` 需 2.1.328+）。
- ✅ 超时默认：command/http/mcp_tool 600s、prompt 30s、agent 60s，部分事件下调。
- ✅ `SessionStart` 只支持 `command` 与 `mcp_tool`。

### 5.4 workflows/

- ✅ JS 脚本编排多子代理，写成 `agent()` / `parallel()` / `pipeline()`。
- ✅ 并发**默认 16**（CPU 少时更低），`CLAUDE_CODE_WORKFLOW_MAX_CONCURRENT_AGENTS` 可调 **1–256**（v2.1.269+）。
- ✅ 扇出时共享首个代理 prompt 缓存的其余代理最多延迟 5 秒启动。
- ✅ `/deep-research` 是唯一内置 workflow（依赖 WebSearch）。
- ⚠️ 项目级 `.claude/workflows/` + 个人级 `~/.claude/workflows/`；`/workflows` 监控，按 `s` 保存。

### 5.5 agent-memory/

- ⚠️ 子代理设 `memory: project` 后使用 `.claude/agent-memory/<name>/MEMORY.md`。
- ✅ 每次加载**前 200 行或 25KB**，超出不加载；超限写入成功但报错要求重写索引。
- ✅ 用户自动记忆在 `~/.claude/projects/<project>/memory/MEMORY.md` 🖥️

## 6. CLI 与会话能力

不在 `.claude/` 里配置，属于 CLI 入口或运行模式；⚠️ 项未逐页核对，用前查 `claude --help` 或官方文档。

| 能力 | 说明 | 依据 |
|---|---|---|
| 后台会话 / 后台代理 | `claude --bg`、`agents`、`attach`、`logs`、`respawn`、`stop` | 🖥️ |
| 云端多代理审查 | `claude ultrareview`，对分支/PR 做云托管 review | 🖥️ |
| auto mode | 权限模式，`claude auto-mode` 查看/重置 | 🖥️ + ⚠️ |
| Code Mode | 用代码代替逐个工具调用；2.1.329 可与 OpenTelemetry 同开 | ✅ changelog |
| 配置迁移 / 清理 | `claude import`、`claude purge`、`gateway`、`install` | 🖥️ |
| 会话内任务视图 | 2.1.329 的 `/tasks` 汇总定时任务、`/loop` 唤醒、会话 forks | ✅ changelog |
| agent teams / ultracode | 多代理协作触发词 | ⚠️ |
| Mods | `mods/` 目录，改 Claude 自身界面 | ⚠️ |

## 7. 速查

```text
指令：CLAUDE.md 根→cwd 合并 → 子目录按需 → rules（无 paths 启动加载）→ AGENTS.md（仅当无 CLAUDE.md）
设置优先级：managed > CLI > local > project > user
MCP 作用域：local > project > user
技能/代理：启动只加载 name+description，正文按需
记忆：前 200 行 / 25KB
workflow 并发：默认 16，可调 1–256
hooks：33 事件 × 5 类型，退出码 2 阻断
```
