#!/usr/bin/env bash
# ==============================================================================
# start-codex.sh
# 
# 零依赖、免安装 Docker 的 Codex 容器环境启动脚本
# 支持 root 最高权限运行、自动检测宿主机 Docker/Podman、便携式免安装运行时
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/.bin"

# 默认配置
DEFAULT_IMAGE="ghcr.io/lublue147-netizen/codex-docker:latest"
IMAGE="${CODEX_IMAGE:-$DEFAULT_IMAGE}"
WORKSPACE_DIR="$(pwd)"
AUTH_DIR="${HOME}/.codex"
RUN_USER="root"

# 终端输出着色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_err() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

show_help() {
    cat <<EOF
Codex 容器环境免安装启动脚本 (支持 root 权限)

用法:
  $(basename "$0") [选项] [-- 容器执行命令...]

选项:
  -w, --workspace <路径>   指定挂载到容器内的项目代码目录 (默认: 当前执行目录)
  -i, --image <镜像名>     指定 Codex 容器镜像 (默认: ${DEFAULT_IMAGE})
  -u, --user <用户>        指定容器内运行身份 (默认: root，可选: node 等)
  -e, --env-file <文件>    指定加载的环境变量文件 (例如 .env)
  -h, --help               显示此帮助信息

示例:
  # 1. 以 root 权限在当前目录启动 Codex CLI
  ./$(basename "$0")

  # 2. 以 root 权限进入容器内置 Bash，可直接 apt-get update && apt-get install 安装任何工具
  ./$(basename "$0") -- bash

  # 3. 指定挂载其他项目目录
  ./$(basename "$0") -w /path/to/my-project

  # 4. 指定非 root 用户运行 (node 用户，UID 1000，支持无密 sudo)
  ./$(basename "$0") -u node

EOF
}

# 1. 解析命令行参数
EXTRA_ARGS=()
ENV_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--workspace)
            WORKSPACE_DIR="$(cd "$2" && pwd)"
            shift 2
            ;;
        -i|--image)
            IMAGE="$2"
            shift 2
            ;;
        -u|--user)
            RUN_USER="$2"
            shift 2
            ;;
        -e|--env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        --)
            shift
            EXTRA_ARGS=("$@")
            break
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

# 2. 检查并确定容器运行时引擎 (Docker / Podman / 便携式免安装运行时)
RUNTIME=""

check_engine() {
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        RUNTIME="docker"
        return 0
    elif command -v podman >/dev/null 2>&1; then
        RUNTIME="podman"
        return 0
    elif [[ -x "${BIN_DIR}/podman" ]]; then
        RUNTIME="${BIN_DIR}/podman"
        return 0
    fi
    return 1
}

setup_portable_runtime() {
    log_info "本地未检测到可用的 Docker 或 Podman 引擎。"
    log_info "正在启用免安装便携式容器运行时 (podman-static)，无需 root/sudo，纯本地解压即可运行..."
    
    mkdir -p "${BIN_DIR}"
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64)
            PODMAN_ARCH="amd64"
            ;;
        aarch64|arm64)
            PODMAN_ARCH="arm64"
            ;;
        *)
            log_err "不支持的系统架构: $ARCH"
            exit 1
            ;;
    esac

    PODMAN_TAR="${BIN_DIR}/podman-linux-${PODMAN_ARCH}.tar.gz"
    PODMAN_URL="https://github.com/mgoltzsche/podman-static/releases/download/v6.1.3/podman-linux-${PODMAN_ARCH}.tar.gz"

    log_info "正在下载轻量级便携运行时 (${PODMAN_ARCH})..."
    curl -fSL --progress-bar "$PODMAN_URL" -o "$PODMAN_TAR"
    
    log_info "解压便携运行时到单独目录: ${BIN_DIR}..."
    tar -xzf "$PODMAN_TAR" -C "${BIN_DIR}" --strip-components=1
    rm -f "$PODMAN_TAR"
    chmod +x "${BIN_DIR}/podman"

    if [[ -x "${BIN_DIR}/podman" ]]; then
        RUNTIME="${BIN_DIR}/podman"
        log_success "便携式容器运行时配置完成！"
    else
        log_err "便携运行时初始化失败。"
        exit 1
    fi
}

if ! check_engine; then
    setup_portable_runtime
fi

log_info "容器引擎: $RUNTIME"
log_info "运行身份: $RUN_USER"
log_info "Codex 镜像: $IMAGE"
log_info "工作区挂载目录: $WORKSPACE_DIR"

# 3. 准备挂载目录与持久化凭证
mkdir -p "$WORKSPACE_DIR"
mkdir -p "$AUTH_DIR"

RUN_FLAGS=(
    -it
    --rm
    --security-opt seccomp=unconfined
    --user "$RUN_USER"
    -v "${WORKSPACE_DIR}:/workspace"
    -v "${AUTH_DIR}:/root/.codex"
    -v "${AUTH_DIR}:/home/node/.codex"
    -w "/workspace"
)

# 4. 处理环境变量传递 (优先使用 OPENAI_API_KEY)
if [[ -n "$OPENAI_API_KEY" ]]; then
    RUN_FLAGS+=(-e "OPENAI_API_KEY=$OPENAI_API_KEY")
fi

if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
    RUN_FLAGS+=(--env-file "$ENV_FILE")
elif [[ -f "${SCRIPT_DIR}/.env" ]]; then
    RUN_FLAGS+=(--env-file "${SCRIPT_DIR}/.env")
fi

# 5. 启动 Codex 容器环境
log_info "正在以 $RUN_USER 权限启动 Codex 容器环境..."
exec $RUNTIME run "${RUN_FLAGS[@]}" "$IMAGE" "${EXTRA_ARGS[@]}"
