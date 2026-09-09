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

1. **Overview** — a 2–4 sentence paragraph (not a bullet) that explains the
   release at a high level: the main themes, who benefits, and any notable
   upgrades or behavioural changes operators should know about.
2. Grouped bullet-point sections. Use only the sections that have content,
   in this order:
   - `### Features` — new capabilities.
   - `### Improvements` — enhancements, performance, refactors that users feel.
   - `### Bug Fixes` — corrected behaviour.
   - `### Maintenance` — dependency bumps, chores, internal/CI changes.
3. Each change is one bullet, written as **1–2 full sentences** that describe
   both *what* changed and *why it matters / the user-facing impact* — do not
   merely restate the PR title. End each bullet with the PR reference in
   parentheses, e.g. `(#169)`. Group multiple related PRs into one bullet when
   it reads better, listing each reference.

## Writing rules

- **Public-facing tone.** Write for customers/operators of the product, not for
  the internal team. Describe the user-visible impact and the benefit, not the
  implementation details.
- **Be descriptive.** Each bullet should give enough context for a reader who did
  not see the code to understand what changed and what it means for them. Prefer
  active voice and present tense ("Adds…", "Fixes…", "Upgrades…"). Aim for
  substance over brevity, but stay on-topic — no filler.
- **Translate internal jargon.** Expand or drop ticket prefixes (e.g. `PARA-123`)
  and internal branch names (e.g. `fix/PARA-20911/managed-sync-trial-disabled`
  → "Fixes managed-sync being incorrectly disabled for trial accounts"). Keep
  version numbers and the names of user-facing components (e.g. OpenObserve,
  Karpenter, bastion, AKS, Managed Redis).
- **Infer impact from context.** Use the PR title, labels, and the commit log to
  reason about what the change does for the user, and state it plainly.
- **Categorize from signals.** Use PR labels and conventional-commit prefixes
  (`feat`, `fix`, `chore`, `refactor`, `docs`, `perf`, `ci`) plus the title text
  to choose the section.
- **Never invent changes.** Only describe what is present in the PRs/commits. If
  a PR is purely internal noise (e.g. merge commits, formatting), omit it or fold
  it into `Maintenance`.
- If there are no meaningful changes, output a single line: `- No notable changes in this release.`

## Example shape (illustrative only — do not copy the content)

```markdown
This release strengthens Azure deployments and improves first-time install
reliability. Operators on Azure gain managed Redis and more flexible cluster
networking, while a fix to S3 permissions removes a common blocker on brand-new
AWS deployments.

### Features
- Adds support for Azure Managed Redis and managed-sync deployments, so Azure
  operators no longer need to self-host Redis and can keep instances in sync
  automatically. (#157)

### Improvements
- Upgrades the managed Kubernetes version to 1.34, bringing newer node features
  and longer upstream support. (#150)

### Bug Fixes
- Fixes an S3 ACL error that previously blocked brand-new deployments from
  provisioning their storage buckets. (#166)

### Maintenance
- Bumps the OpenObserve logging image to v0.91.0 for the latest stability and
  security fixes. (#169)
```
