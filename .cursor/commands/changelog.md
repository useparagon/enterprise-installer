# Changelog Generator

Generate a concise, **public-facing** release changelog as Markdown bullet points
from a set of merged pull requests and their commits.

> Adapted from the `changelog-pdf-generator` agent skill. The PDF-rendering
> behaviour has been intentionally removed — this command produces **Markdown
> bullet points only** for use as the body of a GitHub Release.

## Inputs you will be given

The caller appends a data block describing one release window:

- `Repository` — `owner/repo`.
- `Release` (`to_tag`) and `Previous release` (`from_tag`) — the git tags
  bounding the window.
- `Merged pull requests` — a list of PRs merged in the window, each with its
  number, title, author, and labels.
- `Commit log` — the raw `git log` between the two tags (titles + bodies),
  useful for extra context when a PR title is terse.

## What to produce

Output **only** the changelog Markdown — no preamble, no explanation, no code
fences around the whole thing, and **no PDF**.

Structure:

1. A single short intro sentence (one line) summarizing the release at a high
   level (what changed for users overall).
2. Grouped bullet-point sections. Use only the sections that have content,
   in this order:
   - `### Features` — new capabilities.
   - `### Improvements` — enhancements, performance, refactors that users feel.
   - `### Bug Fixes` — corrected behaviour.
   - `### Maintenance` — dependency bumps, chores, internal/CI changes.
3. Each change is one bullet. End the relevant bullets with the PR reference in
   parentheses, e.g. `(#169)`. Group multiple related PRs into one bullet when
   it reads better, listing each reference.

## Writing rules

- **Public-facing tone.** Write for customers/operators of the product, not for
  the internal team. Describe the user-visible impact, not the implementation.
- **Be descriptive but concise.** One clear sentence per bullet. Prefer active
  voice and present tense ("Adds…", "Fixes…", "Upgrades…").
- **Translate internal jargon.** Expand or drop ticket prefixes (e.g. `PARA-123`),
  internal branch names, and code-only details. Keep version numbers and the
  names of user-facing components (e.g. OpenObserve, Karpenter, bastion).
- **Categorize from signals.** Use PR labels and conventional-commit prefixes
  (`feat`, `fix`, `chore`, `refactor`, `docs`, `perf`, `ci`) plus the title text
  to choose the section.
- **Never invent changes.** Only describe what is present in the PRs/commits. If
  a PR is purely internal noise (e.g. merge commits, formatting), omit it or fold
  it into `Maintenance`.
- If there are no meaningful changes, output a single line: `- No notable changes in this release.`

## Example shape (illustrative only — do not copy the content)

```markdown
This release focuses on logging stability and Kubernetes upgrades.

### Features
- Adds optional bastion host support for private cluster access. (#142)

### Improvements
- Upgrades the managed Kubernetes version to 1.34 for newer node features. (#150)

### Bug Fixes
- Fixes an S3 ACL error that blocked brand-new deployments. (#166)

### Maintenance
- Bumps the OpenObserve image to v0.91.0. (#169)
```
