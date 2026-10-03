---
description: "Rules for maintaining the '## Branches' and '## Copilot Token Usage' sections of README.md — consistent table formatting, dynamic content sourced only from real repo/session data, never fabricated numbers"
applyTo: "**/README.md"
---

# README Branches & Token Usage — Agent Rules

## Overview

Many Copilot-modernised repos document their development history directly in
`README.md` via two tables:

1. **`## Branches`** — one row per development branch, describing the
   modernisation effort and linking to the Copilot instruction file(s) that
   guided it.
2. **`## Copilot Token Usage`** — one row per Copilot session, with real
   token/turn counts pulled from session records.

The **formatting** of these sections must stay consistent across projects.
The **contents** must always be regenerated from real, verifiable data for
the specific repo — never copied, guessed, or extrapolated from another
project or from a prior draft.

---

## The Problem

It is tempting to "fill in" these tables with plausible-looking numbers when
exact data isn't immediately on hand — e.g. rounding turn counts, inventing a
session name that sounds right, or reusing an example value from a template.
This has happened in practice: a token usage table was committed with numbers
like "7,147,562 input tokens / 116 turns" for a session that didn't match any
real session, alongside a "guidance" section built entirely from invented
session names and turn counts.

**Fabricated stats are worse than no stats.** They look authoritative,
erode trust in the README, and cannot be reproduced or audited.

---

## Rule: Every number must be sourced, not estimated

Before writing or updating either table:

1. Enumerate the actual branches in the repo (`git branch -r`, or the
   project's session/PR history) — do not rely on memory of what branches
   "should" exist.
2. Pull real per-session token/turn/model stats from Copilot's session store
   (e.g. via the `session_store_sql` tool, querying `sessions` joined with
   `assistant_usage_events` or `events`, filtered to this repo). Never use
   `turns` tool output alone as a stand-in for token counts — actually
   aggregate `input_tokens` / `output_tokens`.
3. If a number cannot be verified (e.g. a session was deleted, or usage data
   isn't available), omit that row or mark the field `N/A` — do not
   interpolate a plausible-looking value.
4. Cross-check: does the branch name in the table match a branch that
   actually exists on the remote? Does the session summary match what that
   session actually did? If either can't be confirmed, don't include it.

---

## `## Branches` table format

Keep the intro sentence and header exactly as below; only the body rows
change per project:

```markdown
## Branches

Each branch represents a distinct modernisation effort, guided by a corresponding Copilot instruction file.

| Branch | Description | Instructions |
|--------|-------------|--------------|
| [`<branch-name>`](../../tree/<branch-name>) | <one-line description of the effort> | [<file>.instructions.md](.github/copilot/instructions/<file>.instructions.md) |
```

Rules:
- One row per feature/modernisation branch, in **chronological order**
  (oldest first) by branch creation date.
- Do not include transient branches (README-only edits, sync/merge branches,
  token-usage housekeeping) unless the project intentionally documents all
  dev sessions rather than curated feature branches — confirm scope with the
  user if ambiguous.
- Description is a single sentence stating what changed and why, not an
  implementation log.
- If a branch's work is guided by more than one instruction file, list all of
  them as comma-separated links in the same cell.
- Link format is fixed: `[`branch-name`](../../tree/branch-name)` for
  branches, `[filename](.github/copilot/instructions/filename)` for
  instructions.

---

## `## Copilot Token Usage` table format

```markdown
## Copilot Token Usage

Actual per-session token usage, pulled from Copilot session records.

| Session | Branch | Model(s) | Input Tokens | Output Tokens | Turns |
|---------|--------|----------|-------------:|--------------:|------:|
| <session summary> | `<branch-name>` or *(no dedicated branch)* | <model(s) actually used> | <real input tokens> | <real output tokens> | <real turn count> |
| **Total** | | | **<sum>** | **<sum>** | **<sum>** |
```

Rules:
- One row per Copilot session that touched this repo, in chronological order.
- `Model(s)` lists every distinct model actually used in that session
  (comma-separated) — not a single assumed model for the whole project.
- Numbers use thousands separators (`7,147,562`), right-aligned columns.
- Always include a **Total** row summing input tokens, output tokens, and
  turns across all listed sessions.
- Do not add narrative "guidance" subsections (model selection advice, mode
  selection advice, etc.) unless they are derived from the same verified
  numbers in the table above and clearly reference real session names. Prefer
  omitting speculative analysis entirely over risking unverifiable claims.

---

## When the user supplies explicit content

If the user provides exact branch names, descriptions, token counts, or table
rows to insert, use them as given — do not re-query session stores or verify
against remote branches. The verification workflow below applies only when
regenerating from scratch without user-supplied data.

---

## Workflow for regenerating these sections

1. Query real session data for the repo (branch, summary, model(s), token
   totals, turn count) — do not reuse values from a previous README revision
   without re-verifying them.
2. Confirm actual remote branch names (`git fetch && git branch -r`) since a
   session's local/working branch name may have been renamed before push.
3. Rebuild both tables fully from that data, preserving the exact intro text,
   header row, and link formats above.
4. Do not touch any other section of the README (Origin, Screenshots, etc.).
5. Commit with a message describing what was corrected/updated, and note in
   the PR description if this replaces previously inaccurate or fabricated
   content.
