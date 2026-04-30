# Parallel Pillar Subagents

**Date:** 2026-04-30
**Status:** Approved
**Scope:** `agents/tops-laravel-reviewer.md` — Phase E.1 parallelization
**Depends on:** `2026-04-30-per-pillar-sweeps-design.md` (must be merged first)

## Problem

The per-pillar sweeps design (Phase E.1) runs each pillar sequentially within the reviewer agent. With 3-5 pillars loaded, this means 3-5 sequential analysis passes over the same diff. Parallelizing them would significantly reduce review wall-clock time.

## Solution

Dispatch each pillar sweep as a separate subagent using `model: "sonnet"`, all launched in a single message so they run concurrently. The main reviewer collects the JSON findings from all subagents, then runs E.2 (merge/dedup) and E.3 (suggestion validation) itself.

### Change 1: Add Agent tool to reviewer

Add `Agent` to the reviewer's frontmatter tools list:

```
tools: Read, Grep, Glob, Bash, Write, Agent, mcp__gitlab__*
```

### Change 2: Restructure Phase E.1 to dispatch parallel subagents

Instead of the reviewer analyzing each pillar sequentially in its own reasoning, it:

1. Reads each loaded pillar's SKILL.md content (already done in Phase D).
2. Constructs a self-contained prompt for each pillar containing:
   - The pillar's full SKILL.md rules
   - The diff + full file content for all changed files (from Phase B)
   - The JSON finding schema (without `id` — assigned later by the reviewer)
   - Instructions to return ONLY a JSON array of findings
3. Dispatches all pillar subagents in a single message with `model: "sonnet"`.
4. Collects the JSON arrays returned by each subagent.

### Subagent prompt template

```
You are analyzing a Laravel PR/MR diff against a single ruleset.

## Rules

{content of the pillar's SKILL.md}

## Changed Files

{for each changed file:}
### {relative/path/to/File.php}

**Diff:**
{unified diff}

**Full file content:**
{full current content}

{end for each}

## Your Job

Walk every rule in the ruleset above against each changed file.
For each violation found, emit a JSON object:

{
  "severity": "CRITICAL|IMPORTANT|MINOR",
  "category": "...",
  "description": "1-3 sentence plain-English description",
  "file": "relative/path/to/File.php",
  "line": "42" or "42-58" or null,
  "suggestion": "1-2 sentence concrete fix"
}

Return ONLY a JSON array of findings. If no violations, return [].
Do not include any commentary outside the JSON array.
```

### What does NOT change

- **Phases A-D** — preflight, changed files, Pint, pillar loading — unchanged.
- **Phase E.2** — merge/dedup — unchanged, operates on combined findings from all subagents.
- **Phase E.3** — suggestion validation — unchanged, runs in the main reviewer after merge.
- **Phases F-I** — verdict, render, post, terminal summary — unchanged.
- **Pillar SKILL.md files** — no modifications needed.
- **Fixture mode** — works the same; subagents receive fixture file content instead of real PR diff.
- **Hard rules** — unchanged.

### Why Sonnet for subagents

Each pillar subagent has a focused task (~13 rules against a diff), but some pillars require deeper reasoning (security: tracing data flow for SQL injection; eloquent: detecting N+1 across file boundaries). Sonnet provides good reasoning quality at speed. If cost becomes a concern, switching to Haiku is a one-word change.

## Acceptance criteria

- Pillar subagents run in parallel (dispatched in a single message).
- Each subagent returns a clean JSON array of findings.
- The main reviewer merges, deduplicates, validates suggestions, and renders the comment exactly as before.
- Existing test fixtures (`clean`, `dirty`) continue to pass.
- Review wall-clock time decreases compared to sequential sweeps.
