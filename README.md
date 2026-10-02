# Codex Docker 最小化隔离运行环境

这是一个轻量、最小化、零依赖且具备 Root 权限的 OpenAI Codex CLI 容器化运行方案。

## 特色与优势

1. **容器内 Root 最高权限支持**：
   - 默认直接以 `root` 用户身份运行，在容器内拥有完整管理权限。你可以随时在容器内置终端执行 `apt-get update && apt-get install <软件包>`、安装 Python/Rust/Go 等语言工具链，自由排查或构建项目。
   - 容器内同时配置了免密 `sudo`（`node ALL=(ALL) NOPASSWD:ALL`），兼顾 root 运行与普通用户切换。
2. **宿主机零依赖 / 不需要安装 Docker**：
   - 启动脚本 `start-codex.sh` 会自动检测系统是否安装了 Docker 或 Podman。
   - **如果本机未安装任何容器引擎**，脚本会自动就地拉取便携式免安装的 `podman-static`（放置在项目目录 `.bin/` 下），无需 `sudo`、无需系统包管理器，即可直接启动容器！
3. **本地免构建 / 免安装开发依赖**：
   - 本地无需运行庞大的 `docker build` 或全局安装 Node.js/Codex。
   - 配套 GitHub Actions CI/CD 流水线，在 GitHub 云端自动完成多架构（`amd64` / `arm64`）镜像打包并推送到 GitHub Container Registry (`ghcr.io`) 或 Docker Hub。
4. **极简镜像体积**：
   - 基于精简版 `node:22-bookworm-slim`，仅保留 Codex CLI 必需的基础工具（`git`, `curl`, `jq`, `bash`, `sudo`）。
   - 彻底清理 apt 缓存与 npm 缓存，对比动辄数 GB 的通用镜像，体积保持在最小化。
5. **数据持久化与会话保存**：
   - 挂载宿主机 `~/.codex` 目录，登录凭证与会话持久化保存，重启容器无需重新登录。

---

## 目录结构

```text
codex-docker/
├── Dockerfile                      # 最小化镜像构建定义 (支持 root 与 sudo)
├── entrypoint.sh                   # 容器执行入口脚本
├── .dockerignore                   # 忽略不必要文件
├── start-codex.sh                  # 核心免安装启动脚本 (支持 root/user 切换)
├── start-docker.sh                 # 快捷软链接 (指向 start-codex.sh)
├── .env.example                    # 环境变量配置模板
├── .gitignore                      # Git 忽略配置
├── README.md                       # 说明文档
└── .github/
    └── workflows/
        └── docker-build-push.yml   # GitHub Actions 云端自动构建推送流水线
```

---

## 快速使用

### 1. 一键启动 Codex 交互环境 (默认 root 身份)

直接运行启动脚本（默认将当前目录作为项目工作区挂载到容器中）：

```bash
chmod +x start-codex.sh
./start-codex.sh
```

### 2. 进入容器内置终端 (以 root 身份安装新工具)

```bash
./start-codex.sh -- bash
# 在容器内可以直接使用 root 权限安装软件：
# apt-get update && apt-get install -y python3 python3-pip
```

### 3. 指定非 root 身份运行 (普通用户)

若希望以普通开发用户运行：
```bash
./start-codex.sh -u node
```

### 4. 指定挂载其他项目代码目录

```bash
./start-codex.sh -w /path/to/your/project
```

### 5. 传入环境变量

你可以复制模板配置 API 密钥：
```bash
cp .env.example .env
# 编辑 .env 填入 OPENAI_API_KEY
```
或者在启动时直接传入：
```bash
OPENAI_API_KEY="sk-..." ./start-codex.sh
```

---

## GitHub 云端自动构建与推送镜像

本项目包含完整的 GitHub Actions 流水线（`.github/workflows/docker-build-push.yml`）：

1. 将本项目推送到 GitHub 仓库（例如 `lublue147-netizen/codex-docker`）。
2. GitHub Actions 将自动触发多架构（`linux/amd64`, `linux/arm64`）镜像构建。
3. 镜像自动推送至 `ghcr.io/<你的用户名>/codex-docker:latest`。
4. （可选）如果你还想推送到官方 Docker Hub，只需在 GitHub 仓库的 **Settings -> Secrets and variables -> Actions** 中添加：
   - `DOCKERHUB_USERNAME`: 你的 Docker Hub 用户名
   - `DOCKERHUB_TOKEN`: 你的 Docker Hub Access Token
