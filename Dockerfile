FROM node:22-bookworm-slim

LABEL maintainer="lublue147-netizen"
LABEL description="Minimal isolated Docker environment for OpenAI Codex CLI"

ENV DEBIAN_FRONTEND=noninteractive \
    NODE_ENV=production \
    HOME=/home/codex

# 1. 仅安装运行 Codex CLI 所需的最小核心工具集并清理缓存
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    bash \
    jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 2. 全局安装最小化的 @openai/codex CLI，并清理 npm 缓存
RUN npm install -g @openai/codex --omit=dev \
    && npm cache clean --force

# 3. 创建非 root 用户 codex (UID 1000) 确保宿主机挂载文件权限正常
RUN groupadd -g 1000 codex \
    && useradd -u 1000 -g codex -m -s /bin/bash codex \
    && mkdir -p /workspace /home/codex/.codex \
    && chown -R codex:codex /workspace /home/codex

# 4. 拷贝启动入口脚本
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER codex
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["codex"]
