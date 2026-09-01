#!/bin/bash
set -euo pipefail

# version of charts, must be semver and doesn't have to match Paragon appVersion
version="2026.08.31"

# defaults
provider="aws"
tag=""

# parse flags
usage() {
  echo "Usage: ./prepare.sh [-p <provider>] [-t <tag>]"
  echo ""
  echo "Options:"
  echo "  -p <provider>  aws|azure|gcp|k8s (default: aws)"
  echo "  -t <tag>       Git tag to fetch"
  echo "  -h             Show this help"
  exit "${1:-0}"
}

while getopts "t:p:h" opt; do
  case $opt in
    t) tag="$OPTARG" ;;
    p) provider="$OPTARG" ;;
    h) usage ;;
    \?) usage 1 ;;
  esac
done

# if provider is not provided, use aws
if [[ -z "$provider" ]]; then
  provider="aws"
else
  # verify provider is one of the allowed values
  if [[ ! "$provider" =~ ^(aws|azure|gcp|k8s)$ ]]; then
    echo "Error: Invalid provider '$provider'. Must be one of: aws, azure, gcp, k8s"
    exit 1
  fi
fi

# Resolve charts/files/service-inputs.json for update-charts.mjs.
# Local/dev: git archive from -t <tag>.
# Spacelift: before_init sets PARAGON_SERVICE_INPUTS_JSON after fetching
# charts/files/service-inputs.json from the VERSION git tag (or a mount at
# /mnt/workspace/service-inputs.json for local-preview).
temp_dir=$(mktemp -d)
trap "rm -rf $temp_dir" EXIT
input_json=""

mounted_inputs="${PARAGON_SERVICE_INPUTS_JSON:-/mnt/workspace/service-inputs.json}"
in_git=false
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  in_git=true
fi

if [[ -f "${mounted_inputs}" ]]; then
  input_json="${temp_dir}/service-inputs.json"
  cp "${mounted_inputs}" "${input_json}"
  echo "Using service-inputs from ${mounted_inputs}"
elif [[ "${in_git}" == "true" ]]; then
  git fetch --tags --quiet 2>/dev/null || true

  if [[ -z "$tag" ]]; then
    echo "No tag provided, attempting to use latest tag"
    tag=$(git tag --sort=-v:refname | head -n 1)
    if [[ -z "$tag" ]]; then
      echo "Error: No tags found in this repository"
      exit 1
    fi
    echo "Using latest tag: $tag"
  fi

  if ! git show-ref --tags --quiet "refs/tags/$tag"; then
    echo "Error: Tag '$tag' not found"
    exit 1
  fi

  repo_root=$(git rev-parse --show-toplevel)
  if ! (cd "$repo_root" && git archive --format=tar "$tag") | tar -xf - -C "$temp_dir"; then
    echo "Error: Failed to extract files from git tag '$tag'"
    exit 1
  fi
  input_json="$temp_dir/charts/files/service-inputs.json"
else
  echo "Error: Not in a git repository and no service-inputs file found."
  echo "  For Spacelift, before_init fetches charts/files/service-inputs.json"
  echo "  from the VERSION git tag, or mount it at /mnt/workspace/service-inputs.json"
  echo "  (local-preview) / set PARAGON_SERVICE_INPUTS_JSON."
  exit 1
fi

if [[ ! -f "$input_json" ]]; then
  echo "Error: Input JSON file not found: $input_json"
  exit 1
fi

# allow calling from other directories
script_dir=$(dirname "$(realpath "$0")")

have() { command -v "$1" >/dev/null 2>&1; }

# Write per-chart fixtures from the input JSON. Spacelift's Alpine runner has no
# node, so fall back to the python3 port (identical output).
if have node; then
  node "$script_dir/scripts/update-charts.mjs" "$input_json"
elif have python3; then
  python3 "$script_dir/scripts/update-charts.py" "$input_json"
else
  echo "Error: need node or python3 to generate chart fixtures"
  exit 1
fi
workspaces=$script_dir/$provider/workspaces

# aws, azure and gcp use terraform, k8s uses helm from dist
if [[ "$provider" == "k8s" ]]; then
    destination=$script_dir/dist
else
    destination=$script_dir/$provider/workspaces/paragon/charts
fi

echo "ℹ️ preparing: $provider"

# create charts folder as needed
mkdir -p $destination

# Mirror src into dest, dropping any entry whose name matches one of the excludes.
# Spacelift's runner has no rsync, so fall back to tar + prune.
mirror_charts() {
    local src="$1" dest="$2"
    shift 2
    local excludes=("$@") name

    if [[ ! -d "$src" ]]; then
        echo "Error: chart source missing: $src" >&2
        return 1
    fi

    if have rsync; then
        local args=(-aq --delete)
        for name in "${excludes[@]}"; do
            args+=(--exclude="$name")
        done
        rsync "${args[@]}" "$src" "$dest"
    else
        rm -rf "$dest"
        mkdir -p "$dest"
        # pipefail (script-level) so a failed tar does not leave an empty dest.
        (cd "$src" && tar -cf - .) | (cd "$dest" && tar -xf -)
        for name in "${excludes[@]}"; do
            find "$dest" -depth -name "${name%/}" -exec rm -rf {} +
        done
    fi

    if [[ -z "$(find "$dest" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
        echo "Error: chart mirror left empty destination: $dest" >&2
        return 1
    fi
}

# copy charts to provider destination
if [[ "$provider" == "k8s" ]]; then
    # For k8s provider, copy everything including example.yaml and bootstrap
    mirror_charts "$script_dir/charts/" "$destination"
else
    # For terraform providers (aws, azure, gcp), exclude example.yaml and bootstrap
    mirror_charts "$script_dir/charts/" "$destination" 'example.yaml' 'values.placeholder.yaml' 'bootstrap/'
fi

# BSD shasum (macOS) vs sha256sum (Linux). Spacelift Alpine ships BusyBox
# sha256sum, which rejects GNU's -b; we only use the hex field ($1), so omit -b.
if have shasum; then
    sha256=(shasum -a 256)
else
    sha256=(sha256sum)
fi

# Portable in-place sed (BSD/macOS vs GNU/Linux). Spacelift workers are Linux.
# update version using hash of chart folders
shopt -s nullglob
charts=("$destination"/*/)
shopt -u nullglob
if [[ ${#charts[@]} -eq 0 ]]; then
    echo "Error: no charts found under $destination after mirror" >&2
    exit 1
fi
for chart in "${charts[@]}"
do
    # sha256 hash of all files in the chart folder with paths sorted then stripped for consistency across providers
    if [[ -z "$(find "$chart" -type f -print -quit)" ]]; then
        echo "Error: chart has no files: $chart" >&2
        exit 1
    fi
    hash=$(find "$chart" -type f | LC_ALL=C sort | xargs "${sha256[@]}" | awk '{print $1}' | "${sha256[@]}" | awk '{print $1}' | cut -c1-8)
    if [[ ! "$hash" =~ ^[0-9a-f]{8}$ ]]; then
        echo "Error: failed to hash chart $chart (got '$hash')" >&2
        exit 1
    fi
    if [[ "$(uname -s)" == "Darwin" ]]; then
        find "$chart" -type f -exec sed -i '' -e "s/__PARAGON_VERSION__/${version}-${hash}/g" {} +
    else
        find "$chart" -type f -exec sed -i -e "s/__PARAGON_VERSION__/${version}-${hash}/g" {} +
    fi
    if grep -rql '__PARAGON_VERSION__' "$chart" 2>/dev/null; then
        echo "Error: __PARAGON_VERSION__ placeholders remain under $chart (sed in-place failed?)" >&2
        exit 1
    fi
    echo "$(basename "$chart"): $hash"
done

# copy main.tf.example files as needed
if [[ "$provider" != "k8s" ]]; then
    mkdir -p $workspaces/paragon/.secure

    if [[ ! -f "$workspaces/infra/main.tf" ]]; then
        cp "$workspaces/infra/main.tf.example" "$workspaces/infra/main.tf"
    fi
    if [[ ! -f "$workspaces/paragon/main.tf" ]]; then
        cp "$workspaces/paragon/main.tf.example" "$workspaces/paragon/main.tf"
    fi

    create_values_yaml() {
        local file="$1"
        local source="$script_dir/charts/values.placeholder.yaml"

        if [[ ! -f "$file" ]]; then
            cp "$source" "$file"
        fi
    }

    generate_tfvars() {
        local vars_file="$1"
        local out_file="$2"

        if [[ -f "$out_file" ]]; then
            return
        fi

        # Placeholder tfvars are for local runs only; on Spacelift the values come
        # from context TF_VAR_* and there is no node to generate them.
        if ! have node; then
            echo "skipping $out_file (no node)"
            return
        fi

        node "$script_dir/scripts/generate-tfvars.mjs" "$vars_file" "$out_file" "$provider"
    }

    generate_tfvars "$workspaces/infra/variables.tf" "$workspaces/infra/vars.auto.tfvars"
    generate_tfvars "$workspaces/paragon/variables.tf" "$workspaces/paragon/vars.auto.tfvars"
    create_values_yaml "$workspaces/paragon/.secure/values.yaml"
fi

echo "✅ preparations complete!"
