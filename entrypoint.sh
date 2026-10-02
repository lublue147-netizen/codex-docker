#!/bin/bash
set -e

# 如果没有提供参数，默认启动 codex 交互界面
if [ $# -eq 0 ]; then
  exec codex
fi

# 如果第一个参数是以 '-' 开头的 flag，则作为 codex 参数执行
if [ "${1#-}" != "$1" ]; then
  exec codex "$@"
fi

# 否则直接执行传入的命令（例如 bash, sh, git 等）
exec "$@"
