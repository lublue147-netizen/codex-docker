FROM node:22-bookworm-slim

LABEL maintainer="lublue147-netizen"
LABEL description="Minimal isolated Docker environment for OpenAI Codex CLI with root privileges"

ENV DEBIAN_FRONTEND=noninteractive \
    NODE_ENV=production \
    HOME=/root

# 1. 安装 Codex CLI 最小运行依赖 + sudo 工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    bash \
    jq \
    sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 2. 全局安装最小化的 @openai/codex CLI，并清理 npm 缓存
RUN npm install -g @openai/codex --omit=dev \
    && npm cache clean --force

# 3. 创建必要目录与配置免密 sudo（支持 root 直接运行，同时也支持切换 node 用户执行 sudo）
RUN mkdir -p /workspace /root/.codex /home/node/.codex \
    && echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node \
    && chmod 0440 /etc/sudoers.d/node \
    && chown -R node:node /home/node

# 4. 拷贝启动入口脚本
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 默认直接以 root 用户运行，拥有完整管理权限（可随时 apt install 安装额外依赖）
USER root
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["codex"]
