# WeKnora issue 修复规矩

这份文件只约束「从 GitHub issue 到可合入 Pull Request」的做法。`cli/AGENTS.md` 仍是 CLI 的输出契约，两边不要混用。

目标仓库是上游 [Tencent/WeKnora](https://github.com/Tencent/WeKnora)。本仓库 `wangrui19971019/WeKnora` 是它的 fork。修 issue 的分支从上游 `main` 拉出，推到 fork，再向上游开 PR。不要把修复提交到 fork 的 `main`，也不要只在 fork 内部开 PR。这份规矩文件本身留在 fork，不要放进给上游的 diff。

## 选 issue

只做同时满足这些条件的 issue：

- 在 `Tencent/WeKnora` 上处于 open。
- 用 `bug_report.yml` 或同等信息写清了现象、复现、期望和实际行为。标题是 `[Bug]: `。
- 没有已经打开的 PR。动手前再搜一次 `is:pr` 和 issue 编号。
- 不是安全漏洞。漏洞按 `SECURITY.md` 私下报告，不进公开 issue，也不进公开 PR。
- 第一版 PR 能在不改产品语义的前提下把 issue 关上。需要维护者先做产品决定的（例如把 Notion 整库拆成每条记录）先不做。

有人认领但超过一周没有 PR 时，在 issue 里说明后再做。刚认领且计划还有效的，不并行开第二份实现。

当前队列按这个顺序，开工前仍要复核「没有新 PR」：

1. [#4021](https://github.com/Tencent/WeKnora/issues/4021) 钉钉 `Validate` 的四条残留边界。只按 issue 里写的四条收紧，并改 `internal/datasource/connector/dingtalk` 的测试。
2. [#3867](https://github.com/Tencent/WeKnora/issues/3867) 问题生成关闭后，旧问句仍进入召回和 rerank。只做消费侧：配置关闭时不拼 passage、不召回问句向量；存量用 `is_enabled=false` 停用。不用 `IsQuestionCurrent` 当修复条件，不删除向量，不改生成质量。
3. [#4029](https://github.com/Tencent/WeKnora/issues/4029) Markdown 相对图片被浏览器按 SPA 路由解析成 404。只解析 `images/a.png`、`./images/a.png` 这类相对地址，并用 `FolderPath` 加文件名在同一知识库里定位。不按文件名模糊匹配。

跳过 [#4046](https://github.com/Tencent/WeKnora/issues/4046)：嵌入页去掉 `@` 是 `patchEmbedChatPayload` 的安全约束。跳过 [#3313](https://github.com/Tencent/WeKnora/issues/3313) 的整单修复：重试修不掉「整库合成一个文档」这个产品决定。

## 分支

```bash
git fetch upstream main
git checkout -b <branch> upstream/main
```

没有 `upstream` 时：`git remote add upstream https://github.com/Tencent/WeKnora.git`。

Cursor 云端代理的分支名用 `cursor/<主题>-e073`，全小写。一个 issue 一条分支，一个逻辑一个 commit。提交说明用 Conventional Commits：`fix:`、`test:`、`docs:`、`refactor:`。

`origin/main` 若落后于 `upstream/main`，修复分支仍然从 `upstream/main` 拉，不要先把落后的 fork main 混进来。

## 实现

- 只改该 issue 点名的行为，并补回归测试。现有测试若把错误行为写成了规格，要改测试并在 PR 里说明。
- Go 改动提交前对改过的文件执行 `gofmt`。前端改动跑对应测试；动到 TypeScript 或 Vue 时再跑 `npm run type-check`。
- 不提交 `.env`、`.env.lite`、密钥、数据库和构建产物。`.gitignore` 已忽略 `.*` 中的环境文件，以及 `WeKnora-lite`、`data/weknora.db`。
- 实现使用 Grok 4.7。公开可比的是 CursorBench 4.0：Grok 4.7 Extra High 46.3%，Composer 2.5 27.7%。没有 Composer 2.6 的公开分数。Composer 2 的 61.3% 和 Composer 2.5 的 63.2% 是更早的 CursorBench，不能和 4.0 的 46.3% 放在一起比。

## 本地验证

提交前，对照 README Contributing：

```bash
git fetch upstream main
git diff --check upstream/main...HEAD
golangci-lint run --new-from-rev=upstream/main ./...
go test ./path/to/changed/package -count=1
```

`make fmt && make lint && make test` 能跑就跑。全量失败如果来自既有基线或环境，在 PR 的 Testing 里写明命令和失败输出，同时保留本次改动的定向测试结果。

改动路径会触发这些 PR 流水线，提交前先在本地跑对应的那一档：

| 改动 | 流水线 |
|---|---|
| 根模块 `*.go`（排除 `cli/`、`client/`、`docreader/`）、`migrations/`、`config/` | App：diff 上的 `gofmt`、`go vet`、`go test`、`go build ./cmd/server`；另加 Go Lint（只看本次 diff） |
| `frontend/**` | Frontend：`npm test`、`npm run type-check`、`npm run build` |
| `docreader/**` | DocReader |
| `cli/**` | CLI：ubuntu / macos / windows，Go 1.26 |
| `helm/**` | Helm chart lint |
| `mcp-server/**` | MCP server 测试 |
| `third_party/anydoc-go/**`、`internal/infrastructure/docparser/**` | Anydoc。无关 PR 不要碰这些路径 |

Go 1.26，前端 Node 24。

## 对抗 review

写完并跑过定向测试之后，单独做一轮审查，不沿用写代码时的结论。审查要试图否定这个补丁：

- 复现步骤是否仍能打出原问题。
- 新测试是否只锁住了实现细节，而没有锁住 issue 里的期望。
- 是否改动了 issue 没要求的行为，尤其是默认开启、删除数据、放宽权限。
- 是否会让根目录列举失败被当成「无法确定」而放行，或让匿名嵌入请求重新带上 `mentioned_items`。
- diff 是否含格式噪音、生成文件、密钥或这份 `AGENTS.md`。
- 对应流水线在本地是否已经有同等检查。

审查认为补丁不成立时，先改代码再重新跑测试，然后再 push。

## Push 和上游 PR

```bash
git push -u origin HEAD
```

然后向上游开 PR，而不是给 fork 开 PR：

- `owner`: `Tencent`
- `repo`: `WeKnora`
- `head`: `wangrui19971019:<分支名>`
- `base`: `main`
- `maintainer_can_modify`: true
- 标题使用 Conventional Commits，例如 `fix(dingtalk): tighten validate sampling`
- 正文使用 `.github/pull_request_template.md`
- `Fixes #<issue 编号>` 必须指向 `Tencent/WeKnora` 上的 issue

PR 打开后看上游 CI。失败就在同一条分支上修、再 push。不自己合并，不 force push，不改别人的 PR。

## 本机运行

这台环境没有 systemd。Docker 使用 `fuse-overlayfs`（`/etc/docker/daemon.json`），因为根文件系统已经是 overlay，再套一层 overlay 会 `invalid argument`。守护进程若没在听 `/var/run/docker.sock`，在 tmux 里执行：

```bash
sudo dockerd --host=unix:///var/run/docker.sock
```

标准栈：

```bash
sg docker -c 'docker compose up -d'
```

网页是 http://localhost ，API 是 http://localhost:8080 ，健康检查是 `curl http://127.0.0.1:8080/health`。容器之间若互不通，把 `iptables-legacy` 的 `FORWARD` 策略设为 `ACCEPT` 后再 `docker restart WeKnora-app`。Ollama 和其它 profile 默认不开。界面类 bug 用这套 Docker 复现；纯逻辑 bug 以包测试为准。
