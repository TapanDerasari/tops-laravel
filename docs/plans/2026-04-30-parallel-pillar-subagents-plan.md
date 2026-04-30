# Parallel Pillar Subagents — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Parallelize Phase E.1 pillar sweeps by dispatching each pillar as a separate Sonnet subagent, reducing review wall-clock time.

**Architecture:** Add the `Agent` tool to the reviewer's toolset, then rewrite Phase E.1 to dispatch one subagent per loaded pillar in a single message. Each subagent receives the pillar's SKILL.md rules + the diff/file content and returns a JSON array of findings. The main reviewer merges results in E.2 and validates suggestions in E.3 as before.

**Tech Stack:** Markdown (agent prompt), Claude Agent tool with `model: "sonnet"`

**Design doc:** `docs/plans/2026-04-30-parallel-pillar-subagents-design.md`

---

### Task 1: Add Agent tool to reviewer frontmatter

**Files:**
- Modify: `agents/tops-laravel-reviewer.md:4`

**Step 1: Edit the tools line**

Change line 4 from:

```
tools: Read, Grep, Glob, Bash, Write, mcp__gitlab__get_merge_request_details, mcp__gitlab__get_merge_request_changes, mcp__gitlab__list_merge_request_notes, mcp__gitlab__comment_on_merge_request, mcp__gitlab__get_project, mcp__gitlab__list_projects
```

to:

```
tools: Read, Grep, Glob, Bash, Write, Agent, mcp__gitlab__get_merge_request_details, mcp__gitlab__get_merge_request_changes, mcp__gitlab__list_merge_request_notes, mcp__gitlab__comment_on_merge_request, mcp__gitlab__get_project, mcp__gitlab__list_projects
```

Only `Agent` is added, after `Write`.

**Step 2: Commit**

```bash
git add agents/tops-laravel-reviewer.md
git commit -m "feat: add Agent tool to reviewer for parallel pillar dispatch"
```

---

### Task 2: Rewrite Phase E.1 for parallel subagent dispatch

**Files:**
- Modify: `agents/tops-laravel-reviewer.md:98-124` (Phase E.1 section)

**Step 1: Replace Phase E.1 content**

Replace the `#### Phase E.1 — Per-pillar sweeps` section (from line 100 through line 124, ending just before `#### Phase E.2`) with:

```markdown
#### Phase E.1 — Per-pillar sweeps (parallel)

11. For each loaded pillar (excluding `laravel-pint`, which is handled by Phase C), construct a self-contained subagent prompt containing:
    - The pillar's full SKILL.md content (read during Phase D).
    - The diff + full file content for every changed file (collected during Phase B).
    - The JSON finding schema (without `id` — assigned later in E.2).
    - Instructions to return ONLY a raw JSON array of findings.

12. Dispatch ALL pillar subagents in a single message so they run concurrently. Use this configuration for each:
    - `model: "sonnet"`
    - `description: "Pillar: <pillar-name>"`

    Use this prompt template for each subagent (filling in the variables):

    ```
    You are analyzing a Laravel PR/MR diff against a single ruleset.

    ## Rules

    {full content of the pillar's SKILL.md}

    ## Changed Files

    {for each changed file:}
    ### {relative/path/to/File.php}

    **Diff:**
    {unified diff from git diff <base>...HEAD -- <file>}

    **Full file content:**
    {full current content of the file}

    {end for each}

    ## Your Job

    Walk every rule in the ruleset above against each changed file.
    For each violation found, emit a JSON object with these fields:

    - "severity": "CRITICAL", "IMPORTANT", or "MINOR"
    - "category": free text (e.g. "Data Integrity", "Project Rule Violation")
    - "description": 1-3 sentence plain-English description, may quote code
    - "file": relative path to the file
    - "line": "42" or "42-58" or null
    - "suggestion": 1-2 sentence concrete fix, may include code

    Return ONLY a JSON array of finding objects. If no violations, return [].
    Do not include any commentary, explanation, or markdown outside the JSON array.
    ```

13. Collect the JSON arrays returned by all subagents. If a subagent returns malformed output (not a valid JSON array), log a warning in the terminal summary and treat that pillar as having 0 findings.
```

**Step 2: Update step numbers in E.2, E.3, and Phases F-I**

Phase E.1 now ends at step 13 (was step 11). All subsequent step numbers shift by +2:

- E.2 steps 12, 13, 14 → 14, 15, 16
- E.3 steps 15, 16, 17 → 17, 18, 19
- Phase F step 18 → 20
- Phase G step 19 → 21
- Phase H steps 20-23 → 22-25
- Phase I step 24 → 26

Also update the internal cross-reference in E.3: "Re-run the full dedup process (step 13)" → "Re-run the full dedup process (step 15)"

**Step 3: Verify step numbering**

Read the full file and confirm steps flow 1-26 without gaps. Confirm E.3's cross-reference to the dedup step is correct.

**Step 4: Commit**

```bash
git add agents/tops-laravel-reviewer.md
git commit -m "feat: parallelize Phase E.1 with per-pillar Sonnet subagents

Each loaded pillar is dispatched as a separate subagent in a single
message for concurrent execution. Subagents return JSON finding arrays.
Main reviewer merges, deduplicates, and validates suggestions as before."
```

---

### Task 3: Verify test fixtures still pass

**Files:**
- Read: `tests/run-tests.sh` (no modification)
- Possibly modify: `tests/fixtures/dirty/expected.json` (if counts shift)

**Step 1: Run test harness**

Run: `bash tests/run-tests.sh`
Expected: Both `[clean] PASS` and `[dirty] PASS`

**Step 2: If counts shift**

The parallel subagent approach may find slightly different counts than the sequential approach. If a fixture fails:
- Counts below minimums → investigate, the parallel approach should find at least as many
- Counts above maximums → widen `max_*` in `expected.json`
- Missing substrings → verify categories/descriptions still contain expected keywords

**Step 3: Commit any adjustments**

```bash
git add tests/fixtures/
git commit -m "test: adjust fixture expectations for parallel pillar subagents"
```

---

### Task 4: Push and update PR

**Step 1: Push to existing branch**

Run: `git push`

The `feat/per-pillar-sweeps` branch already has a PR open (#1). The push updates it.

**Step 2: Verify PR updated**

Run: `gh pr view 1 --json commits --jq '.commits | length'`
Expected: commit count increases to reflect the new commits.
