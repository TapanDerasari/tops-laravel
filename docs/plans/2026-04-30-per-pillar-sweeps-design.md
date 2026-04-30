# Per-Pillar Independent Sweeps + Suggestion Validation

**Date:** 2026-04-30
**Status:** Approved
**Scope:** `agents/tops-laravel-reviewer.md` — Phase E restructuring

## Problem

The reviewer is stateless — each invocation re-analyzes the full PR/MR diff from scratch. Developers report:

1. First review run finds 3-5 issues.
2. Developer fixes those (often following the reviewer's own suggestions).
3. Second review run finds 2-3 *new* issues that should have been caught the first time.

Root causes:
- **Incomplete first-pass detection:** Analyzing 5-6 pillars (50+ rules) in a single pass spreads LLM attention thin, causing missed findings.
- **Suggestions that introduce new violations:** The reviewer recommends a fix without checking whether that fix triggers rules from a different pillar.

## Solution

Restructure Phase E into three sub-phases. No changes to pillar SKILL.md files. No changes to Phases A-D or F-I.

### Phase E.1 — Per-Pillar Sweeps (replaces step 11)

For each loaded pillar (in order: `project-rules`, `laravel-security`, `laravel-eloquent`, `laravel-best-practices`, `laravel-performance`):
- Analyze the diff + full file content against ONLY this pillar's rules.
- Emit findings with the standard JSON schema.
- Move to the next pillar with a clean slate.

`laravel-pint` is excluded — handled deterministically by Phase C's binary output.

### Phase E.2 — Merge & Deduplicate (replaces steps 12-13)

- Collect all findings from all pillar sweeps + Pint findings from Phase C.
- Deduplicate: same file + same line range + same root cause → keep higher severity, merge categories with `+`.
- Stable sort by severity (CRITICAL > IMPORTANT > MINOR) → file path → line number.

### Phase E.3 — Suggestion Validation (new)

For each CRITICAL or IMPORTANT finding that includes a suggestion:
1. Mentally apply the suggested fix to the code in context.
2. Check the resulting code against ALL loaded pillars.
3. If the suggestion would introduce a new violation:
   - Expand the suggestion to address both the original issue and the secondary one.
   - If the secondary issue is significant enough, emit an additional finding (linked to the original via description).
4. Re-run dedup after any new findings are added.

MINOR suggestions are excluded from validation — style/hygiene findings are unlikely to cascade.

### Example

| Step | What happens |
|------|-------------|
| E.1 (security pillar) | Flags `$request->all()` in `UserController@store` → suggests "use `$request->validated()`" |
| E.3 (validation) | Checks: does a `StoreUserRequest` FormRequest exist? No → expands suggestion to "Create `StoreUserRequest` with rules for name, email, password, then use `$request->validated()`" |
| E.3 (validation) | Checks: would `$request->validated()` trigger any other pillar? No further issues → done |

Without E.3, the developer follows the suggestion, pushes, re-runs review, and gets flagged for missing FormRequest — a wasted round-trip.

## What does NOT change

- Pillar SKILL.md files — no modifications needed.
- Phases A-D (preflight, changed files, Pint, pillar loading) — unchanged.
- Phases F-I (verdict, render, post, terminal summary) — unchanged.
- Fixture mode and test harness — unchanged (the restructured Phase E produces the same output schema).
- Hard rules — unchanged.

## Acceptance criteria

- Single review pass catches all findings that the current two-pass cycle would find.
- Every CRITICAL/IMPORTANT suggestion is self-consistent — applying it does not introduce a new violation detectable by any loaded pillar.
- Existing test fixtures (`clean`, `dirty`) continue to pass.

## Delivery

Separate PR/MR on GitHub.
