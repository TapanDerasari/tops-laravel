---
description: Reads the target project's CLAUDE.md and treats its rules as first-class review findings. Always loaded.
disable-model-invocation: true
---

# project-rules

## When to load
Always loaded by `tops-laravel-reviewer`.

## What to read
At review time, read the following from the target project root (the developer's CWD when running the slash command):
1. `CLAUDE.md` (preferred)
2. `.cursorrules` (fallback)
3. `.editorconfig` (style hints only)
4. Any `*.md` file inside a top-level `docs/standards/` or `docs/conventions/` directory.

## How to apply
Extract rules — especially imperative lines using `must`, `must not`, `never`, `always`, `do not`, `forbidden`, `required`. For each changed file in the PR/MR, check whether any extracted rule is violated.

## Examples of CLAUDE.md rules to detect violations of
- "Never use `Logger::log()` in production code outside `src/scripts/`."
- "All controllers must extend `App\Http\Controllers\BaseController`."
- "Migrations must include `down()` rollback."
- "Use `Str::uuid()` for primary keys."

## How to report
- Severity: `IMPORTANT` by default, unless the rule itself specifies otherwise (e.g., a rule prefixed with "MUST" or "CRITICAL").
- Category: always `Project Rule Violation`.
- Description: quote the rule from `CLAUDE.md` verbatim, then explain the violation in the changed file.
- File:Line: the offending line in the changed file.

## Conflict policy
Project rules outrank pillar rules. If a pillar would accept code that `CLAUDE.md` rejects, the project rule wins.

## Missing CLAUDE.md
If no `CLAUDE.md`/`.cursorrules` is present, emit no findings from this pillar. Do not warn — many projects do not use these files.
