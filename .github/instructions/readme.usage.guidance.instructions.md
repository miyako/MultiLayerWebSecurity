---
description: "Rules for auditing Copilot session history and writing model/mode selection guidance in project READMEs — assessing whether each session used an appropriately sized model and interaction mode"
applyTo: "**/README.md"
---

# Copilot Usage Guidance — Agent Rules

## Overview

After completing a series of Copilot sessions on a project, the README should include a usage guidance section that reviews each session's model and mode choices against its actual task complexity. This helps future sessions (and users) pick cheaper models and better interaction modes from the start.

The guidance is based on **real session data** — token counts, turn counts, and task descriptions — not hypothetical estimates. Every claim must be traceable to an actual session record.

---

## Data Collection

### Step 1: Gather session records

Query the Copilot session store for all sessions associated with the project. Collect:

| Field | Source | Notes |
|-------|--------|-------|
| Session name | `sessions.summary` | Human-readable task description |
| Branch | `sessions.branch` | The working branch; some sessions (chats, syncs) may not have one |
| Model(s) | `events.usage_model` | Distinct models used across the session's turns |
| Input tokens | `events.usage_input_tokens` | Sum across all turns |
| Output tokens | `events.usage_output_tokens` | Sum across all turns |
| Turns | `turns` table | Count of user/assistant turn pairs |

### Step 2: Build the token usage table

Present raw data in a table with right-aligned numeric columns:

```markdown
| Session | Branch | Model(s) | Input Tokens | Output Tokens | Turns |
|---------|--------|----------|-------------:|--------------:|------:|
| Fix syntax errors | `branch-name` | Claude Opus 4.6 | 3,334,377 | 14,968 | 48 |
| Update README | `branch-name` | Claude Sonnet 5 | 591,373 | 2,299 | 13 |
| **Total** | | | **3,925,750** | **17,267** | **61** |
```

**Formatting rules:**
- Use thousands separators for token counts (e.g., `3,334,377`)
- Right-align numeric columns with `:` in the header separator
- Sessions without a dedicated branch use `*(no dedicated branch)*`
- Include a bold **Total** row at the bottom
- List sessions in chronological order

---

## Model Assessment

### Task complexity tiers

Classify each session's task into one of these complexity tiers, then compare against the model actually used.

| Tier | Task characteristics | Appropriate model |
|------|---------------------|-------------------|
| **Trivial** | File operations (`git add`, commit, push), simple text edits | Haiku 4.5 |
| **Mechanical** | Pattern-based refactors, find-and-replace with clear rules, documentation updates, table formatting | Sonnet 5 |
| **Moderate** | Multi-file edits with some judgment, UI/CSS changes, well-scoped feature work with instruction files | Sonnet 5 |
| **Complex** | Architectural redesign, cross-file reasoning about unfamiliar domain conventions, novel API integration | Opus 4.6 |

### Assessment categories

After classifying each session, assign it to one of three categories:

| Category | Meaning | Criteria |
|----------|---------|----------|
| **Appropriate** | Model matched task complexity | Tier and model align per the table above |
| **Overspend** | Model was more capable than the task required | Opus used for trivial/mechanical tasks, or Sonnet used for trivial tasks |
| **Borderline** | Reasonable arguments for either direction | Task straddles two tiers; model choice is defensible but not clearly optimal |

### Signals that a session was over-served

- **Low output-to-input ratio** with a high-tier model: the model consumed many input tokens (context) but produced little output, suggesting the task was simple enough that a smaller model could handle it.
- **Mechanical pattern**: the task follows a repetitive find/replace or property-edit pattern, even if it touched many files and ran for many turns.
- **Git-only operations**: fetch, merge, push, branch management — no code reasoning.
- **Text editing**: README updates, table formatting, documentation — no code analysis.

### Signals that Opus was justified

- **Cross-file architectural reasoning**: understanding how multiple components interact to make a design decision.
- **Domain-specific edge cases**: the task required knowledge of a niche technology (e.g., 4D language conventions, XLIFF structure) where the model needed broad training data.
- **Novel or very recent APIs**: APIs so new that smaller models may not have adequate training coverage.
- **High design ambiguity**: the task required making architectural choices, not just executing a known pattern.

### Writing the assessment

**Single-session or few-session projects (fewer than 4 sessions):** Skip the
3-subsection table structure below. Instead, write 1--2 paragraphs stating the
task complexity tier, the model used, whether it was appropriate or overkill,
and a one-line recommendation for future similar tasks. End with a bold
`**Recommendation:**` line.

**Projects with 4+ sessions:** Use the full structure below.

Structure the assessment as three subsections with tables:

```markdown
## Model Selection Assessment

[1-2 sentence overview of model mix used across the project.]

### Sessions where model choice was appropriate

[Introductory sentence.]

| Session | Model | Turns | Task | Why it fits |
|---------|-------|------:|------|-------------|
| ... | ... | ... | ... | ... |

### Sessions where Opus was likely overkill

[Introductory sentence noting the cost impact.]

| Session | Model | Turns | Input Tokens | Task | Recommended model |
|---------|-------|------:|-------------:|------|-------------------|
| ... | ... | ... | ... | ... | ... |

[Call out the single largest overspend by name and token count.]

### Borderline -- Sonnet 5 probably sufficient

| Session | Model | Turns | Task | Notes |
|---------|-------|------:|------|-------|
| ... | ... | ... | ... | ... |
```

**Writing rules:**
- Use `--` (double hyphen) instead of em dashes for ASCII compatibility
- Keep "Why it fits" and "Notes" cells to one sentence
- In the "Recommended model" column, lead with the model name, then a brief reason after `--`
- Include the Input Tokens column only in the "overkill" table to highlight wasted spend
- If no sessions fall into a category, omit that subsection entirely

---

## Mode Assessment

### Mode definitions

| Mode | When to use | Risk |
|------|-------------|------|
| **Interactive** | Tasks needing mid-stream corrections, unfamiliar domains, exploratory work | Slowest; requires human attention |
| **Plan** | Complex multi-file tasks where scope and approach should be reviewed before execution | Plan review adds a step, but catches scope drift early |
| **Autopilot** | Well-scoped tasks with clear specs, mechanical edits, documented instruction files | May go off-track if requirements are ambiguous |

### Assessment signals

**Interactive was correct when:**
- The session log shows mid-stream corrections (wrong command names, missed requirements, URL fixes)
- The task domain was unfamiliar to the agent (novel 4D commands, platform-specific behaviour)
- The user changed direction or added scope during the session

**Autopilot would have been fine when:**
- The task has a documented instruction file with clear rules
- The edit is mechanical (property changes, refactors, documentation)
- The session completed with few or no corrections

**Plan mode would have helped when:**
- High turn count suggests significant iteration that could have been avoided
- The agent made errors that a plan review would have caught (wrong conventions, missed files)
- The task spanned many files with interdependencies

### Writing the mode guidance

Use prose paragraphs with bold lead-ins, not tables. Group sessions by mode recommendation:

```markdown
### Mode Selection Guidance

**Interactive mode was the right choice for most sessions.** [Cite specific sessions
and what corrections were needed.]

**With documented instruction files, these task types are now autopilot-ready:**
- [Category 1] -- [example sessions]
- [Category 2] -- [example sessions]

**Plan mode would have helped with:**
- **[Session name]** -- [what went wrong and how plan review would have caught it]
```

**Writing rules:**
- Reference sessions by name, not branch
- Include turn counts as evidence when citing high-iteration sessions
- Be specific about what corrections were needed (not just "many corrections")
- Only recommend plan mode when there is concrete evidence of avoidable iteration

---

## Section Placement in README

The usage guidance sections go **after** the token usage table and **before** any screenshots or appendices:

```
## Branches
[branches table]

## Copilot Token Usage
[token usage table]

## Model Selection Assessment
[assessment sections]

## Screenshots (if any)
[images]
```

---

## Anti-Patterns

### ❌ Fabricating session data

Never invent session names, token counts, or turn counts. Every entry must come from actual session records. If session data is unavailable for a session, omit it and note the gap.

### ❌ Assessing without real context

Don't classify a session as "overkill" or "justified" based solely on the session name. Read the actual task description, branch content, or instruction file to understand what the session did before making a judgment.

### ❌ Recommending Haiku for everything simple

Haiku 4.5 is appropriate for truly trivial tasks (file operations, git commands). But even simple code edits benefit from Sonnet 5's better instruction-following. Reserve Haiku recommendations for tasks with no code reasoning at all.

### ❌ Ignoring turn count context

A high turn count does not automatically mean the task was complex. It may indicate the model struggled (suggesting a stronger model was needed) or that the user made many small requests (suggesting the task was actually simple but interactive). Look at the ratio of turns to output tokens for clues.

### ❌ Using smart quotes or em dashes

GitHub README rendering and CLI tooling handle ASCII punctuation most reliably. Use `--` instead of em dashes, straight quotes instead of curly quotes, and `...` instead of ellipsis characters.

### ❌ Making the guidance section longer than the token usage table

The assessment should be concise and scannable. If the guidance is longer than the data it analyses, it is too verbose. Aim for one sentence per table cell and short prose paragraphs.

---

## Checklist

- [ ] Token usage table includes all sessions from session store queries
- [ ] Numeric columns are right-aligned and use thousands separators
- [ ] A **Total** row is present at the bottom of the token usage table
- [ ] Every session is classified into appropriate / overkill / borderline
- [ ] Classifications are justified with task descriptions, not just session names
- [ ] The largest overspend is called out explicitly with token count
- [ ] Mode guidance references specific sessions and concrete correction examples
- [ ] Plan mode is recommended only when there is evidence of avoidable iteration
- [ ] All text uses ASCII punctuation (no smart quotes, no em dashes)
- [ ] Section order follows: Token Usage > Model Assessment > Mode Guidance > Screenshots

---

## References

- Copilot session store schema: `sessions`, `turns`, `events`, `session_files`, `session_refs` tables
- Session store query tool: `session_store_sql` with DuckDB syntax for cloud, SQLite for local
- GitHub Copilot model options: Haiku 4.5, Sonnet 5, Opus 4.6 (current as of July 2026)
- Copilot interaction modes: interactive, plan, autopilot
