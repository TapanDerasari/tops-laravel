# Design — `tops-laravel` Claude Code plugin (v1: `tops-laravel-reviewer`)

**Date:** 2026-04-28
**Author:** tapan@topsinfosolutions.com
**Status:** Approved (brainstorm complete) — ready for implementation plan

## 1. Goal

Build an organisation-wide Claude Code plugin, `tops-laravel`, that ships Laravel-focused skills and a **PR/MR code reviewer** as its first deliverable. The reviewer evaluates a teammate's open PR (GitHub) or MR (GitLab) against Laravel best practices, Pint style rules, Eloquent patterns, security, performance, and the project's own `CLAUDE.md` rules — then posts a single, structured summary comment on the PR/MR.

## 2. Scope of v1

**In scope**
- One plugin, `tops-laravel`, distributable via `--plugin-dir` (and later via an org-internal git marketplace).
- One slash command: `/tops-laravel:review <pr-or-mr>`.
- One subagent: `tops-laravel-reviewer`, owning the workflow.
- Five pillar skills + one dynamic project-rules pillar.
- Both GitHub and GitLab in v1, using:
  - GitHub → `gh` CLI (already installed on developer machines)
  - GitLab → `mcp__gitlab__*` MCP tools (already installed on developer machines)
- Pint runs as the real binary (`./vendor/bin/pint --test`) against changed files.
- Single summary comment per review (no inline per-line comments in v1).
- Local invocation only — developer must have the PR/MR branch checked out.

**Out of scope (v2+)**
- Inline per-line review comments.
- CI / headless mode.
- Auto-fix of Pint violations.
- Security advisories on dependencies (composer audit).
- Test coverage delta reporting.

## 3. Constraints & assumptions

- Developer machines have `gh` (authenticated) and the GitLab MCP server (authenticated) configured.
- Developer runs the slash command from the Laravel project's working directory with the PR/MR branch checked out at HEAD.
- `composer install` has been run (so `./vendor/bin/pint` exists). If missing, the Pint pillar is skipped with a note in the comment — review still completes.
- The plugin itself does not require PHP at install time; it only uses the project's local Pint binary at run time.

## 4. Plugin structure

```
tops-laravel/
├── .claude-plugin/
│   └── plugin.json                       # name, version, author, description
├── README.md                             # install + usage
├── commands/
│   └── review.md                         # /tops-laravel:review entry point
├── agents/
│   └── tops-laravel-reviewer.md          # subagent: workflow + tool restrictions
├── skills/
│   ├── laravel-best-practices/SKILL.md   # general Laravel idioms
│   ├── laravel-pint/SKILL.md             # how to run + interpret pint
│   ├── laravel-eloquent/SKILL.md         # N+1, mass-assignment, scopes, relationships
│   ├── laravel-security/SKILL.md         # auth, validation, SQL injection, XSS, CSRF
│   ├── laravel-performance/SKILL.md      # eager loading, indexes, queues, caching
│   └── project-rules/SKILL.md            # how to read & apply project CLAUDE.md
└── tests/
    ├── fixtures/                         # sample diffs (good + bad)
    └── run-tests.sh                      # smoke harness
```

**Why this layout**
- `commands/review.md` is a thin slash-command template. It forwards `$ARGUMENTS` to the subagent and returns the agent's output.
- `agents/tops-laravel-reviewer.md` defines the workflow, restricts tools (Read, Bash, Grep, Glob, Write to `/tmp/` only, GitLab MCP tools), and pulls in pillar skills on demand.
- Each pillar skill is a focused, line-per-rule checklist that the team can extend by appending lines — no agent code change needed.
- `project-rules` is special: it reads `CLAUDE.md`, `.cursorrules`, and `.editorconfig` from the target project at run time and treats their rules as first-class findings (Category: `Project Rule Violation`).

## 5. Runtime workflow

```
1. PARSE ARGUMENT
   - "123"   → GitHub PR #123 (default host)
   - "!456"  → GitLab MR !456
   - URL     → host + ref auto-detected
   - missing → fail with usage message

2. DETECT HOST + FETCH METADATA
   GitHub:  gh pr view <n> --json headRefOid,headRefName,baseRefName,files,title,body
   GitLab:  mcp__gitlab__get_merge_request_details + get_merge_request_changes

3. VERIFY LOCAL CHECKOUT (safety gate)
   - git rev-parse HEAD must equal PR/MR head SHA
   - on mismatch → ABORT: "checkout PR branch first: gh pr checkout <n>"

4. COLLECT CHANGED FILES
   - include: *.php, *.blade.php, composer.json, config/**, routes/**, database/migrations/**
   - skip:    vendor/, node_modules/, *.lock, public/build/

5. RUN PINT
   - ./vendor/bin/pint --test <changed-php-files>
   - capture violations → feed to laravel-pint pillar
   - missing binary → skip pint pillar, note in comment

6. LOAD PILLAR SKILLS BY RELEVANCE
   - always:  laravel-best-practices, laravel-pint, project-rules
   - if app/Models/**         → laravel-eloquent
   - if Controllers/FormRequests/auth → laravel-security
   - if migrations/queries/jobs/loops → laravel-performance

7. ANALYZE
   - read full file content (not only diff) for context
   - apply each loaded skill's checklist
   - emit findings as JSON: { id, severity, category, description, file, line, suggestion }

8. COMPUTE VERDICT
   - any critical            → CHANGES REQUESTED
   - else any important      → CHANGES REQUESTED
   - else only minor         → APPROVED WITH SUGGESTIONS
   - else 0 findings         → APPROVED

9. RENDER MARKDOWN COMMENT (see §6)

10. POST COMMENT
    GitHub:  gh pr comment <n> --body-file /tmp/tops-review-<n>.md
    GitLab:  mcp__gitlab__comment_on_merge_request

11. PRINT TERMINAL SUMMARY
    - link to posted comment, finding counts, verdict
```

**Read-only by design.** The reviewer agent's tool list excludes Edit and restricts Write to `/tmp/` — it cannot modify the working tree.

## 6. Comment format

Modeled on the existing review style at `git.topsdemo.in` (sample MR provided during brainstorm).

```markdown
## Automated Peer Review

**Verdict:** CHANGES REQUESTED
**Issues Found:** 0 critical, 3 important, 4 minor

### Summary
{1–3 paragraphs of plain-English overview: what the MR does, what is correct,
what is wrong, root-cause framing of the most important findings}

### Issues

| # | Severity  | Category               | Description                          | File:Line                |
|---|-----------|------------------------|--------------------------------------|--------------------------|
| 1 | IMPORTANT | Data Integrity         | …                                    | path/File.php:184-249    |
| 2 | IMPORTANT | Project Rule Violation | Logger::info in production service … | path/Service.php:150     |
| 3 | MINOR     | Code Duplication       | …                                    | …                        |

### Required Fixes Before Merge
1. **Issue #1 (Data Loss):** {concrete remediation, suggested code pattern}
2. **Issue #2 (Logger):** Remove `Logger::info(...)` at line 150-153 …
3. **Issue #3 (…):** … like this example: `…`

---
_Generated by `tops-laravel-reviewer` · run locally · `<short-sha>` · `<iso-timestamp>`_
```

**Severity tiers:** `critical | important | minor` (uppercase in the table).
**Categories:** free-text, descriptive (e.g. "Data Integrity", "Project Rule Violation", "Error Handling Inconsistency", "Code Duplication", "Missing Tests", "Eloquent N+1", "Pint Style", "Security: Mass Assignment").

## 7. Pillar skill content (sketch)

Each `SKILL.md` has frontmatter (`description`, `disable-model-invocation: true`) and a body of one-line rules in the form *pattern → why it matters → suggested fix*.

- **laravel-best-practices** — service container vs `new`, single-action controllers, Form Request validation, API Resource classes, route model binding, `config()` vs `env()` outside config files, named routes, no business logic in controllers/models, traits over inheritance.
- **laravel-pint** — Pint output is authoritative; never second-guess it; suggest `pint` to auto-fix.
- **laravel-eloquent** — N+1 (missing `with()`), `whereHas` vs eager constraints, mass-assignment (`$fillable`/`$guarded`), `firstOrCreate` race conditions, soft-delete pitfalls, accessor/mutator naming, relationship return types, avoid `DB::raw` when builder works.
- **laravel-security** — `$request->all()` mass-assignment, missing `FormRequest` validation, `Auth::user()` without policy, raw SQL concatenation, `{!! !!}` in Blade, missing CSRF on state-changing routes, file-upload MIME validation, `Hash::check` vs `===`, route middleware coverage.
- **laravel-performance** — missing eager loads, `Model::all()` on large tables, `count()` in loops, missing FK indexes in migrations, sync queue jobs that should be async, cache misses on expensive computations, chunking for large datasets.
- **project-rules** — read `CLAUDE.md` from project root, parse rules (especially "do not", "must not", "always", "never" lines), apply as findings tagged `Project Rule Violation`. Project rules outrank pillar rules on conflict.

## 8. Error handling

| Condition                         | Behavior                                                                  |
|-----------------------------------|---------------------------------------------------------------------------|
| `gh` / GitLab MCP missing         | Fail fast with exact install/auth command for the relevant host           |
| Not in a git repo                 | Fail fast with clear message                                              |
| HEAD ≠ PR/MR head SHA             | Abort with `gh pr checkout <n>` / `git checkout <branch>` instruction     |
| `./vendor/bin/pint` missing       | Continue review; comment notes `Pint: skipped (binary not found)`         |
| API/MCP failure when posting      | Save comment to `/tmp/tops-review-<n>.md`; tell user to paste manually    |
| 0 findings                        | Still post a short `✅ APPROVED — no issues found` comment                 |
| Argument cannot be parsed         | Print usage examples and exit                                             |

## 9. Testing approach

- `tests/fixtures/` holds minimal fake Laravel files paired with expected findings.
- `tests/run-tests.sh` loads the plugin via `claude --plugin-dir ./` and runs the reviewer in a "dry-run" mode (no posting), comparing JSON findings to fixtures.
- Each pillar skill has at least one positive (rule fires) and one negative (rule doesn't fire) fixture.
- Manual smoke test on a real PR before publishing v1.

## 10. Distribution

- **v1 author dogfood:** `claude --plugin-dir /var/www/html/tops-laravel`
- **v1 team rollout:** push the plugin to an org-internal git repo configured as a Claude Code marketplace; teammates install via `/plugin install`.
- **Versioning:** explicit `version` in `plugin.json` (semver), bumped per release.

## 11. Open questions deferred to implementation

- Exact format of the JSON intermediate findings schema (decide during implementation; not user-facing in v1).
- Whether to expose individual pillar skills as standalone slash commands (e.g. `/tops-laravel:eloquent-check`) — possible, deferred to v2 once usage patterns are clear.
- Whether to add a `--dry-run` flag that prints the comment to terminal instead of posting (likely yes — useful for the test harness).

## 12. Decision log (from brainstorm)

| Decision                            | Choice                              | Why                                          |
|-------------------------------------|-------------------------------------|----------------------------------------------|
| Where the reviewer runs             | Locally, against open PR/MR         | Fastest path; no CI changes needed           |
| GitHub vs GitLab in v1              | Both                                | Org uses both; adapter layer is small        |
| GitHub adapter                      | `gh` CLI                            | Already installed on developer machines      |
| GitLab adapter                      | `mcp__gitlab__*` MCP tools          | Already installed; auth handled by MCP       |
| Slash command vs subagent           | Both — command dispatches to agent  | Best UX + clean context + reusable in CI     |
| Comment style                       | Single summary review               | Identical on both hosts; v2 may add inline   |
| File context source                 | Local checkout (HEAD must match)    | Simple, fast, allows real Pint run           |
| Check organisation                  | Thin agent + per-pillar skill files | Editable rules library; team can extend      |
| Severity tiers                      | critical / important / minor        | Matches existing org review style            |
| Project rules                       | First-class via `project-rules`     | Sample MR cited `CLAUDE.md` as authoritative |
