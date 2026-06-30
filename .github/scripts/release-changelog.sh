#!/usr/bin/env bash
#
# release-changelog.sh
#
# Builds a GitHub Release body for a tag window:
#   1. Resolves the from_tag..to_tag window (date-based tags, canary excluded).
#   2. Collects every merged pull request in the window.
#   3. Generates a public-facing bullet-point summary with the Cursor Agent CLI
#      (falls back to a deterministic categorized summary when CURSOR_API_KEY is
#      absent or the CLI fails).
#   4. Writes the composed release body, and optionally creates/updates the
#      GitHub Release tied to to_tag.
#
# It is intentionally split into small functions so the tag-resolution and PR
# collection logic can be exercised locally (see SUBCOMMAND dispatch at bottom).
#
# Required environment:
#   REPO              owner/repo (e.g. useparagon/enterprise-installer)
#   GH_TOKEN          token with repo scope (for the gh CLI)
# Optional environment:
#   INPUT_TO_TAG      explicit end tag    (default: newest stable tag)
#   INPUT_FROM_TAG    explicit start tag  (default: stable tag before to_tag)
#   DRAFT             "true" to publish the release as a draft (default: false)
#   CREATE_RELEASE    "true" to actually create/update the release (default: false)
#   CURSOR_API_KEY    enables the AI summary; without it a fallback is used
#   CURSOR_MODEL      optional model passed to cursor-agent
#   COMMAND_FILE      path to the changelog command (default: .cursor/commands/changelog.md)
#   OUTPUT_DIR        where artifacts are written (default: ./.release-changelog)
#   GITHUB_OUTPUT     when set, resolved tags are exported as step outputs

set -euo pipefail

COMMAND_FILE="${COMMAND_FILE:-.cursor/commands/changelog.md}"
OUTPUT_DIR="${OUTPUT_DIR:-./.release-changelog}"
TAG_GLOB='20[0-9][0-9].*'

log() { printf '%s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

# Newest-first list of stable (non-canary) release tags, by commit creation date.
stable_tags() {
  git for-each-ref --sort=-creatordate \
    --format='%(refname:short)' "refs/tags/${TAG_GLOB}" \
    | grep -v -- '-canary' || true
}

# Resolve the to_tag/from_tag window from inputs + the tag list.
resolve_window() {
  local tags to_tag from_tag
  tags="$(stable_tags)"
  [ -n "$tags" ] || die "No release tags matching '${TAG_GLOB}' found."

  if [ -n "${INPUT_TO_TAG:-}" ]; then
    to_tag="$INPUT_TO_TAG"
  else
    to_tag="$(printf '%s\n' "$tags" | sed -n '1p')"
  fi
  git rev-parse -q --verify "refs/tags/${to_tag}" >/dev/null \
    || die "to_tag '${to_tag}' does not exist."

  if [ -n "${INPUT_FROM_TAG:-}" ]; then
    from_tag="$INPUT_FROM_TAG"
  else
    # First stable tag strictly older than to_tag (by the sorted list order).
    from_tag="$(printf '%s\n' "$tags" \
      | awk -v t="$to_tag" 'found{print; exit} $0==t{found=1}')"
  fi

  if [ -z "$from_tag" ]; then
    log "No previous tag before '${to_tag}'; using repository root as the start."
    from_tag="$(git rev-list --max-parents=0 HEAD | tail -n1)"
  else
    git rev-parse -q --verify "${from_tag}" >/dev/null \
      || die "from_tag '${from_tag}' does not exist."
  fi

  printf '%s\t%s\n' "$from_tag" "$to_tag"
}

# Emit "* <title> by @<author> in <url>" PR lines for the window using GitHub's
# release-notes generator, which correctly handles squash- and merge-commits.
generate_pr_notes() {
  local from_tag="$1" to_tag="$2"
  gh api -X POST "repos/${REPO}/releases/generate-notes" \
    -f tag_name="$to_tag" \
    -f previous_tag_name="$from_tag" \
    --jq '.body' 2>/dev/null || true
}

# Extract unique PR numbers (newest-first preserved) from generated notes.
pr_numbers_from_notes() {
  grep -oE 'pull/[0-9]+' | sed 's#pull/##' | awk '!seen[$0]++'
}

build_changelog() {
  mkdir -p "$OUTPUT_DIR"

  local window from_tag to_tag
  window="$(resolve_window)"
  from_tag="$(printf '%s' "$window" | cut -f1)"
  to_tag="$(printf '%s' "$window" | cut -f2)"
  log "Resolved window: ${from_tag} -> ${to_tag}"

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
      echo "from_tag=${from_tag}"
      echo "to_tag=${to_tag}"
    } >> "$GITHUB_OUTPUT"
  fi

  # --- Collect merged PRs --------------------------------------------------
  local notes pr_numbers pr_list_md
  notes="$(generate_pr_notes "$from_tag" "$to_tag")"
  pr_numbers="$(printf '%s\n' "$notes" | pr_numbers_from_notes)"

  pr_list_md="$OUTPUT_DIR/pr-list.md"
  : > "$pr_list_md"
  if [ -n "$pr_numbers" ]; then
    while IFS= read -r num; do
      [ -n "$num" ] || continue
      gh pr view "$num" --repo "$REPO" \
        --json number,title,author,url,labels \
        --jq '"- [#\(.number)](\(.url)) \(.title) — @\(.author.login)"' \
        2>/dev/null >> "$pr_list_md" || true
    done <<< "$pr_numbers"
  fi
  if [ ! -s "$pr_list_md" ]; then
    # Fallback: derive PR references straight from commit messages in the range.
    git log --pretty='%s' "${from_tag}..${to_tag}" \
      | grep -oE '#[0-9]+' | sort -u \
      | sed 's/^/- /' >> "$pr_list_md" || true
  fi
  [ -s "$pr_list_md" ] || echo "- No merged pull requests found in this window." > "$pr_list_md"
  log "Collected $(grep -c '^-' "$pr_list_md" || echo 0) PR entries."

  # --- Build the data block the AI/fallback summarizes ---------------------
  local ai_input="$OUTPUT_DIR/ai-input.md"
  {
    echo "Repository: ${REPO}"
    echo "Release (to_tag): ${to_tag}"
    echo "Previous release (from_tag): ${from_tag}"
    echo
    echo "Merged pull requests:"
    if [ -n "$pr_numbers" ]; then
      while IFS= read -r num; do
        [ -n "$num" ] || continue
        gh pr view "$num" --repo "$REPO" \
          --json number,title,author,labels \
          --jq '"- #\(.number) \(.title) [labels: \([.labels[].name] | join(", "))] (@\(.author.login))"' \
          2>/dev/null || true
      done <<< "$pr_numbers"
    else
      cat "$pr_list_md"
    fi
    echo
    echo "Commit log (no-merge commits):"
    git log --no-merges --pretty='- %s' "${from_tag}..${to_tag}" | head -300
  } > "$ai_input"

  # --- Generate the summary ------------------------------------------------
  local summary_md="$OUTPUT_DIR/summary.md"
  if generate_ai_summary "$ai_input" "$summary_md"; then
    log "AI summary generated."
  else
    log "Falling back to deterministic summary."
    fallback_summary "$ai_input" "$summary_md"
  fi

  # --- Compose the release body -------------------------------------------
  local body_md="$OUTPUT_DIR/release-body.md"
  {
    cat "$summary_md"
    echo
    echo "## Merged Pull Requests"
    echo
    cat "$pr_list_md"
    echo
    echo "---"
    echo "_**Full Changelog**: https://github.com/${REPO}/compare/${from_tag}...${to_tag}_"
  } > "$body_md"

  log "Release body written to ${body_md}"

  if [ "${CREATE_RELEASE:-false}" = "true" ]; then
    publish_release "$to_tag" "$body_md"
  fi

  printf '%s\n' "$body_md"
}

# Run cursor-agent over the data block; returns non-zero to trigger the fallback.
generate_ai_summary() {
  local ai_input="$1" out="$2"
  [ -n "${CURSOR_API_KEY:-}" ] || { log "CURSOR_API_KEY not set."; return 1; }
  command -v cursor-agent >/dev/null 2>&1 || { log "cursor-agent not on PATH."; return 1; }
  [ -f "$COMMAND_FILE" ] || { log "Command file ${COMMAND_FILE} missing."; return 1; }

  local prompt
  prompt="$(cat "$COMMAND_FILE")
$(printf '\n---\nGenerate the changelog for the following release window. Output Markdown bullet points only.\n\n')
$(cat "$ai_input")"

  local model_args=()
  [ -n "${CURSOR_MODEL:-}" ] && model_args=(--model "$CURSOR_MODEL")

  local agent_log="$OUTPUT_DIR/cursor-agent.log"
  log "Invoking cursor-agent (model: ${CURSOR_MODEL:-default})..."
  local rc=0
  timeout 420 cursor-agent -p "${model_args[@]}" --output-format text "$prompt" \
    > "$out" 2>"$agent_log" || rc=$?

  if [ "$rc" -eq 0 ] && [ -s "$out" ] && grep -q '[^[:space:]]' "$out"; then
    return 0
  fi

  # Surface diagnostics directly in the job log (artifacts may be unavailable).
  if [ "$rc" -ne 0 ]; then
    log "cursor-agent exited with code ${rc}."
  else
    log "cursor-agent returned an empty response."
  fi
  log "----- cursor-agent stderr (begin) -----"
  cat "$agent_log" >&2 || true
  log "----- cursor-agent stderr (end) -----"
  return 1
}

# Deterministic categorized summary from conventional-commit prefixes / labels.
fallback_summary() {
  local ai_input="$1" out="$2"
  awk '
    BEGIN {
      feat=""; imp=""; fix=""; maint="";
    }
    /^- #/ {
      line=$0
      # Strip the leading "- #NNN " marker, keep "#NNN" reference for output.
      num=$2
      title=$0
      sub(/^- #[0-9]+ /, "", title)
      # Drop the trailing [labels: ...] (@author) annotation for readability.
      sub(/ \[labels:.*$/, "", title)
      ref=" (" num ")"
      lower=tolower(title)
      if (lower ~ /^feat/)                       feat = feat "- " title ref "\n"
      else if (lower ~ /^fix/)                   fix  = fix  "- " title ref "\n"
      else if (lower ~ /^(perf|refactor|improve)/) imp = imp "- " title ref "\n"
      else if (lower ~ /^(chore|ci|build|docs|style|test)/) maint = maint "- " title ref "\n"
      else                                       imp  = imp  "- " title ref "\n"
    }
    END {
      print "This release includes the following changes."
      print ""
      if (feat  != "") { print "### Features";     printf "%s\n", feat }
      if (imp   != "") { print "### Improvements"; printf "%s\n", imp }
      if (fix   != "") { print "### Bug Fixes";    printf "%s\n", fix }
      if (maint != "") { print "### Maintenance";  printf "%s\n", maint }
      if (feat=="" && imp=="" && fix=="" && maint=="")
        print "- No notable changes in this release."
    }
  ' "$ai_input" > "$out"
}

publish_release() {
  local to_tag="$1" body_md="$2"
  local draft_flag=()
  [ "${DRAFT:-false}" = "true" ] && draft_flag=(--draft)

  if gh release view "$to_tag" --repo "$REPO" >/dev/null 2>&1; then
    log "Updating existing release ${to_tag}."
    gh release edit "$to_tag" --repo "$REPO" \
      --notes-file "$body_md" --title "$to_tag" "${draft_flag[@]}"
  else
    # The git tag already exists (pushed by the release automation), so we do
    # NOT pass --target: gh attaches the release to the existing tag. Passing a
    # tag name as --target is rejected (target_commitish must be a branch/SHA).
    log "Creating release ${to_tag}."
    gh release create "$to_tag" --repo "$REPO" \
      --title "$to_tag" --notes-file "$body_md" "${draft_flag[@]}"
  fi
}

main() {
  local cmd="${1:-build}"
  case "$cmd" in
    resolve-window) resolve_window ;;
    stable-tags)    stable_tags ;;
    build)          build_changelog ;;
    *) die "Unknown subcommand: ${cmd} (expected: resolve-window | stable-tags | build)" ;;
  esac
}

main "$@"
