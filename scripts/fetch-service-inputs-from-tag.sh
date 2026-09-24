#!/usr/bin/env bash
# Extract charts/files/service-inputs.json from a Paragon release git tag.
# Chart templates may come from a different ref (feature branch); fixtures must
# match the release tag that defines container images and env/secret metadata.
set -euo pipefail

tag="${1:-}"
dest="${2:-charts/files/service-inputs.json}"

if [[ -z "$tag" ]]; then
  echo "Usage: fetch-service-inputs-from-tag.sh <release-tag> [dest-path]" >&2
  exit 1
fi

git fetch --tags --quiet origin 2>/dev/null || git fetch --tags --quiet

if ! git rev-parse "refs/tags/${tag}^{commit}" >/dev/null 2>&1; then
  if ! git rev-parse "${tag}^{commit}" >/dev/null 2>&1; then
    echo "Error: git tag or ref not found: ${tag}" >&2
    exit 1
  fi
fi

if ! git cat-file -e "${tag}:charts/files/service-inputs.json" 2>/dev/null; then
  echo "Error: ${tag} does not contain charts/files/service-inputs.json" >&2
  exit 1
fi

mkdir -p "$(dirname "$dest")"
git show "${tag}:charts/files/service-inputs.json" >"$dest"
echo "Wrote service-inputs.json from tag ${tag} -> ${dest}"
