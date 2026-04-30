# Per-Pillar Sweeps + Suggestion Validation — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restructure Phase E of the tops-laravel-reviewer agent so each pillar analyzes independently, followed by a suggestion-validation pass, to maximize first-run finding coverage.

**Architecture:** Only one file changes: `agents/tops-laravel-reviewer.md`. Phase E (lines 98-113) is replaced with three sub-phases: E.1 (per-pillar sweeps), E.2 (merge & dedup), E.3 (suggestion validation). All other phases and all pillar SKILL.md files are untouched. The dirty fixture's `expected.json` ranges may need widening if the more thorough analysis surfaces additional findings.

**Tech Stack:** Markdown (agent prompt), Bash (test harness)

**Design doc:** `docs/plans/2026-04-30-per-pillar-sweeps-design.md`

---

### Task 1: Create feature branch

**Files:**
- None (git operation only)

**Step 1: Create and checkout feature branch**

Run: `git checkout -b feat/per-pillar-sweeps`
Expected: `Switched to a new branch 'feat/per-pillar-sweeps'`

---

### Task 2: Replace Phase E with Phase E.1 (Per-Pillar Sweeps)

**Files:**
- Modify: `agents/tops-laravel-reviewer.md:98-113`

**Step 1: Replace the Phase E section**

Replace lines 98-113 (from `### Phase E — Analyze` through step 13) with this exact content:

```markdown
### Phase E — Analyze

#### Phase E.1 — Per-pillar sweeps

11. Analyze the diff + full file content one pillar at a time. For each loaded pillar (excluding `laravel-pint`, which is handled by Phase C), sweep in this order:
    1. `project-rules`
    2. `laravel-security` (if loaded)
    3. `laravel-eloquent` (if loaded)
    4. `laravel-best-practices`
    5. `laravel-performance` (if loaded)

    For each pillar sweep:
    - Focus exclusively on that pillar's rules. Do not consider other pillars' rules during this sweep.
    - Walk every rule in the pillar's checklist against the diff + full file content.
    - Emit findings as JSON entries with this schema (collected internally, not shown to the user):
      ```json
      {
        "id": 1,
        "severity": "CRITICAL|IMPORTANT|MINOR",
        "category": "free text, e.g. Data Integrity, Project Rule Violation, Pint Style",
        "description": "1-3 sentence plain-English description, may quote code",
        "file": "relative/path/to/File.php",
        "line": "42" | "42-58" | null,
        "suggestion": "1-2 sentence concrete fix; may include code"
      }
      ```
    - After completing one pillar, move to the next with a clean slate — do not let findings from one pillar bias the next.

#### Phase E.2 — Merge and deduplicate

12. Collect all findings from every pillar sweep in E.1 plus Pint findings from Phase C.
13. De-duplicate: if two pillars produced findings for the same file, same line range, and same root cause, keep the higher-severity entry and merge categories with `+` (e.g. `Eloquent + Performance`).
14. Order: stable sort by `severity` (CRITICAL > IMPORTANT > MINOR), then by file path, then by line.

#### Phase E.3 — Suggestion validation

15. For each CRITICAL or IMPORTANT finding that includes a suggestion:
    - Mentally apply the suggested fix to the code in context of the full file.
    - Check the resulting code against ALL loaded pillars — not just the one that produced the finding.
    - If applying the suggestion would introduce a new violation:
      a. Expand the suggestion to address both the original issue and the secondary one.
      b. If the secondary issue is independently significant, emit it as an additional finding and link it to the original in the description (e.g. "Related to #3 — the suggested fix also requires ...").
16. Re-run dedup (step 13) if any new findings were added.
17. Re-assign sequential `id` values (1, 2, 3, ...) to the final ordered list.
```

**Step 2: Update step numbers in Phases F-I**

The old Phase E ended at step 13. The new Phase E ends at step 17. Update step numbers in subsequent phases:

- Phase F step 14 → step 18
- Phase G step 15 → step 19
- Phase H steps 16-19 → steps 20-23
- Phase I step 20 → step 24

**Step 3: Commit**

```bash
git add agents/tops-laravel-reviewer.md
git commit -m "feat: restructure Phase E into per-pillar sweeps with suggestion validation

Split monolithic analysis into independent per-pillar sweeps (E.1),
merge/dedup (E.2), and suggestion validation (E.3) to maximize
first-pass finding coverage and prevent fix-introduced regressions."
```

---

### Task 3: Widen dirty fixture expected ranges

**Files:**
- Modify: `tests/fixtures/dirty/expected.json`

Per-pillar sweeps will likely surface more findings than the current single-pass analysis. The dirty fixture's `max_*` bounds need to accommodate this without breaking the test.

**Step 1: Read current expected.json and assess**

Current ranges:
- critical: [1, 2]
- important: [4, 8]
- minor: [2, 8]

With independent pillar sweeps, each pillar gets full attention. Findings that were previously missed may now appear. Widen the upper bounds:

```json
{
  "verdict": "CHANGES REQUESTED",
  "min_critical": 1,
  "max_critical": 3,
  "min_important": 4,
  "max_important": 12,
  "min_minor": 2,
  "max_minor": 12,
  "must_contain_substrings": [
    "CHANGES REQUESTED",
    "Mass Assignment|mass assignment|`$request->all()`",
    "raw SQL|SQL injection|DB::raw|DB::select",
    "Project Rule Violation",
    "Log::info",
    "down()|down rollback",
    "$guarded",
    "N+1|eager load|with("
  ],
  "must_not_contain_substrings": ["APPROVED\n", "no issues found"]
}
```

Note: `min_*` values stay the same — the per-pillar approach should find at least as many as before. Only `max_*` values increase to allow for the expected additional findings.

**Step 2: Commit**

```bash
git add tests/fixtures/dirty/expected.json
git commit -m "test: widen dirty fixture ranges for per-pillar sweep thoroughness"
```

---

### Task 4: Run test fixtures and verify

**Files:**
- Read: `tests/run-tests.sh` (no modifications)

**Step 1: Run the test harness**

Run: `bash tests/run-tests.sh`
Expected: Both `[clean] PASS` and `[dirty] PASS`

**Step 2: If dirty fixture fails with counts outside range**

- If counts are below minimums: investigate — the per-pillar sweeps should find more, not fewer. Check that the Phase E rewrite is correct.
- If counts are above maximums: widen the `max_*` values in `expected.json` and re-run.
- If `must_contain_substrings` check fails: verify the finding categories and descriptions still contain the expected keywords.

**Step 3: If clean fixture fails**

The clean fixture should produce 0 findings (APPROVED). If the more thorough analysis flags something in the clean fixture, either:
- The finding is a false positive → the clean fixture code needs adjusting to be truly clean
- The finding is legitimate → adjust the clean fixture's `expected.json`

**Step 4: Commit any adjustments**

```bash
git add tests/fixtures/
git commit -m "test: adjust fixture expectations after per-pillar sweep validation"
```

---

### Task 5: Push and create PR

**Step 1: Push feature branch**

Run: `git push -u origin feat/per-pillar-sweeps`

**Step 2: Create PR**

```bash
gh pr create --title "feat: per-pillar sweeps + suggestion validation" --body "$(cat <<'EOF'
## Summary

- Restructures Phase E of the reviewer agent into three sub-phases: independent per-pillar sweeps (E.1), merge/dedup (E.2), and suggestion validation (E.3)
- Each pillar now analyzes the diff independently with full attention on its own ruleset, preventing missed findings from LLM attention spread
- Every CRITICAL/IMPORTANT suggestion is validated against all pillars before reporting, preventing fix-introduced regressions

## Problem

Developers reported a back-and-forth loop: first review finds 3-5 issues, developer fixes them, second review finds 2-3 new issues that should have been caught the first time. Root causes: (1) single-pass analysis of 50+ rules spreads LLM attention thin, (2) suggested fixes can introduce violations from other pillars.

## Design doc

See `docs/plans/2026-04-30-per-pillar-sweeps-design.md`

## Test plan

- [ ] `fixture:clean` produces APPROVED with 0 critical, 0 important
- [ ] `fixture:dirty` produces CHANGES REQUESTED with expected finding counts
- [ ] All `must_contain_substrings` present in dirty fixture output
- [ ] Run `bash tests/run-tests.sh` — both fixtures PASS
EOF
)"
```

**Step 3: Report PR URL**
