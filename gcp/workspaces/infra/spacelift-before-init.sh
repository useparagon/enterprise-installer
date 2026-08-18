#!/usr/bin/env bash
# Spacelift before_init entrypoint (project_root = gcp/workspaces/infra).
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/scripts/spacelift/before_init-infra.sh" gcp
