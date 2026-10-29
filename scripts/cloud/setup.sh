#!/usr/bin/env bash
# Setup for the Claude Code cloud environment used by the nightly routine.
set -euo pipefail

cd "$(dirname "$0")/../.."

if ! command -v uv >/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sudo env UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh
fi

uv sync
uv run ansible-galaxy collection install -r ansible/requirements.yml
uv run ansible --version
