#!/usr/bin/env bash
# Spacelift before_init entrypoint (project_root = aws/workspaces/paragon).
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/scripts/spacelift/before_init-paragon.sh"
