# tops-laravel-reviewer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship v1 of the `tops-laravel` Claude Code plugin: a `/tops-laravel:review <pr-or-mr>` slash command that dispatches to a `tops-laravel-reviewer` subagent, which evaluates the locally-checked-out branch against six pillar skills (Laravel best-practices, Pint, Eloquent, Security, Performance, Project-Rules) and posts a single "Automated Peer Review" markdown comment on the GitHub PR (via `gh`) or GitLab MR (via the gitlab MCP).

**Architecture:** Pure-markdown Claude Code plugin — no compiled code. The slash command is a thin entry that delegates to the subagent. The subagent owns the workflow (parse arg → verify HEAD SHA → fetch diff → run Pint → load relevant pillar skills → analyze → render comment → post). Each pillar is a `SKILL.md` rule library the agent loads on demand. A bash test harness runs the agent in `--dry-run` mode against curated fixtures and asserts expected findings appear.

**Tech Stack:** Claude Code plugin format (`.claude-plugin/plugin.json`, `skills/`, `agents/`, `commands/`), `gh` CLI, GitLab MCP server, Laravel Pint, bash for the test harness.

**Reference design doc:** `/var/www/html/tops-laravel/docs/plans/2026-04-28-tops-laravel-reviewer-design.md`

**Conventions for every task in this plan:**
- All paths are relative to plugin root: `/var/www/html/tops-laravel/`
- After every task, commit with a `feat:` / `test:` / `docs:` / `chore:` prefix.
- **Never** add `Co-Authored-By: Claude` (or any Claude/Anthropic) trailer to commits or PR/MR comments. (Memory: `feedback_no_claude_coauthor_trailer.md`)
- All commits go on `main`.
- Test the plugin loads after each major task: `claude --plugin-dir /var/www/html/tops-laravel /help` and confirm no plugin-load errors.

---

## Phase 1 — Plugin skeleton

### Task 1: Plugin manifest and directory tree

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `skills/.gitkeep`
- Create: `agents/.gitkeep`
- Create: `commands/.gitkeep`
- Create: `tests/fixtures/.gitkeep`
- Create: `.gitignore`

**Step 1: Create directory tree**

```bash
cd /var/www/html/tops-laravel
mkdir -p .claude-plugin skills agents commands tests/fixtures
touch skills/.gitkeep agents/.gitkeep commands/.gitkeep tests/fixtures/.gitkeep
```

**Step 2: Write `.claude-plugin/plugin.json`**

```json
{
  "name": "tops-laravel",
  "description": "Tops Infosolutions Laravel toolkit — code review for PRs/MRs against Laravel best practices, Pint, Eloquent, security, performance, and project rules.",
  "version": "0.1.0",
  "author": {
    "name": "Tops Infosolutions",
    "email": "tapan@topsinfosolutions.com"
  }
}
```

**Step 3: Write `.gitignore`**

```
.playwright-mcp/
/tmp/
*.log
.DS_Store
```

**Step 4: Verify plugin loads (smoke test)**

Run: `claude --plugin-dir /var/www/html/tops-laravel -p "/help" 2>&1 | grep -i 'tops-laravel\|error' | head`
Expected: plugin name appears, no load errors.

**Step 5: Commit**

```bash
git add .claude-plugin/ skills/.gitkeep agents/.gitkeep commands/.gitkeep tests/fixtures/.gitkeep .gitignore
git commit -m "chore: scaffold tops-laravel plugin manifest and directory tree"
```

---

### Task 2: README

**Files:**
- Create: `README.md`

**Step 1: Write `README.md`**

````markdown
# tops-laravel

Internal Claude Code plugin for Tops Infosolutions Laravel projects.

## v1 features

- `/tops-laravel:review <pr-or-mr>` — runs an automated peer review on an open
  GitHub PR or GitLab MR and posts a single summary comment.

## Prerequisites

- Claude Code installed and authenticated.
- `gh` CLI installed and authenticated (for GitHub PRs).
- GitLab MCP server installed and authenticated (for GitLab MRs).
- The PR/MR branch checked out locally at HEAD inside the target Laravel project.
- `composer install` run in the target project (so `./vendor/bin/pint` exists).

## Local install for development

```bash
claude --plugin-dir /path/to/tops-laravel
```

## Usage

```text
/tops-laravel:review 123          # GitHub PR #123 (default host)
/tops-laravel:review !456         # GitLab MR !456
/tops-laravel:review https://github.com/org/repo/pull/123
/tops-laravel:review https://git.topsdemo.in/org/repo/-/merge_requests/456
/tops-laravel:review 123 --dry-run   # render comment to terminal, do not post
```

## Layout

- `commands/review.md` — slash command entry point
- `agents/tops-laravel-reviewer.md` — workflow subagent
- `skills/<pillar>/SKILL.md` — rule libraries (one per pillar)
- `tests/` — fixtures and test harness

## Extending the rules

Each pillar skill is a one-rule-per-line markdown checklist. To add a rule, append a line to the relevant `skills/<pillar>/SKILL.md`. No agent code changes needed.
````

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add plugin README"
```

---

## Phase 2 — Pillar skills (rule libraries)

> Each pillar SKILL.md follows the same template:
> 1. YAML frontmatter with `description` and `disable-model-invocation: true`.
> 2. A "When to load this skill" section.
> 3. A flat checklist where each rule is `**<Pattern name>** — <why it matters> — <suggested fix>`.
> 4. A "How to report findings" section pointing back to the agent's JSON-finding schema (defined in Task 9).

### Task 3: laravel-best-practices skill

**Files:**
- Create: `skills/laravel-best-practices/SKILL.md`

**Step 1: Write the skill**

```markdown
---
description: Laravel general best-practice checks (controllers, validation, config, routes). Load when reviewing any PHP file in a Laravel project.
disable-model-invocation: true
---

# laravel-best-practices

## When to load
Always loaded by `tops-laravel-reviewer` for any Laravel PR/MR review.

## Rules

- **Business logic in controllers** — controllers should be thin; move logic to services, actions, or jobs — extract to a service class or a single-action invokable.
- **`new ClassName()` for resolvable dependencies** — bypasses the container; constructor-inject or use `app()` for one-offs.
- **`env()` outside `config/`** — only `config/*.php` may call `env()`; runtime `env()` returns null when config is cached — read from `config()` instead.
- **Missing FormRequest validation** — controllers using `$request->all()` or `$request->input()` for state-changing routes should validate via a `FormRequest` subclass.
- **String routes instead of named routes** — `route('users.show', $id)` over `'/users/'.$id` — survives URL refactors and supports signed URLs.
- **Missing route model binding** — controllers manually fetching by ID (`User::find($id)`) when the route can bind directly (`Route::get('/users/{user}', ...)`).
- **API responses without Resource classes** — returning raw model arrays leaks DB columns; wrap in an `JsonResource`/`ResourceCollection`.
- **Mass `if/else` instead of policy** — authorization checks scattered across controllers; use Gates/Policies and `$this->authorize()`.
- **Magic strings for events/jobs** — dispatching by class reference (`UserRegistered::dispatch()`) over string keys.
- **Inheritance for shared behavior** — prefer traits or composition for cross-cutting concerns; deep model inheritance trees are a smell.
- **Direct facade use in domain layer** — services/domain classes using `Auth::`, `Cache::`, `DB::` directly instead of injected contracts — hurts testability.
- **Hard-coded sleep/sleep_until in jobs** — use queue delays (`->delay()`) and scheduled jobs.
- **Missing `Str::` / `Arr::` helpers** — manual string/array manipulation where a Laravel helper exists is harder to read and skip edge cases.

## How to report

Emit findings using the schema in `agents/tops-laravel-reviewer.md`. Suggested categories: `Best Practice`, `Architecture`, `Maintainability`.
```

**Step 2: Commit**

```bash
git add skills/laravel-best-practices/
git commit -m "feat: add laravel-best-practices pillar skill"
```

---

### Task 4: laravel-pint skill

**Files:**
- Create: `skills/laravel-pint/SKILL.md`

**Step 1: Write the skill**

```markdown
---
description: Laravel Pint style enforcement. Loaded for every review. Defers to the `pint --test` binary as ground truth.
disable-model-invocation: true
---

# laravel-pint

## When to load
Always loaded by `tops-laravel-reviewer` when at least one `*.php` file changed.

## How Pint runs
The reviewer agent runs `./vendor/bin/pint --test <changed-files>` from the project root. Stdout and exit code feed this skill.

## Rules

- **Pint output is authoritative.** Never override or second-guess Pint findings — report them verbatim.
- For each file Pint flags, emit one finding with severity `MINOR`, category `Pint Style`, and suggestion `run \`./vendor/bin/pint <file>\` to auto-fix`.
- If Pint reports more than 10 violations on a single file, collapse into one finding noting the count and the auto-fix command.
- If `./vendor/bin/pint` is missing, do **not** emit findings; instead include a single line in the review summary: `Pint: skipped (./vendor/bin/pint not found — run \`composer install\`)`.
- Never claim a Pint pass for files Pint did not actually inspect.

## How to report

Severity always `MINOR`. Category always `Pint Style`. File is the absolute path Pint reported.
```

**Step 2: Commit**

```bash
git add skills/laravel-pint/
git commit -m "feat: add laravel-pint pillar skill"
```

---

### Task 5: laravel-eloquent skill

**Files:**
- Create: `skills/laravel-eloquent/SKILL.md`

**Step 1: Write the skill**

```markdown
---
description: Eloquent ORM checks — N+1, mass assignment, relationships, scopes. Load when models, repositories, or queries are touched.
disable-model-invocation: true
---

# laravel-eloquent

## When to load
Loaded when any of these change: `app/Models/**`, `app/Repositories/**`, `database/migrations/**`, or any file containing query builder calls (`DB::`, `->where(`, `->whereHas(`, `->with(`).

## Rules

- **N+1 query** — a relationship accessed inside a loop without `->with('relation')` upstream — add eager loading; cite the loop file:line and the model file:line.
- **`Model::all()` on large tables** — full-table read; switch to chunking (`->chunk(100, fn ...)`) or pagination.
- **Mass assignment without `$fillable` or `$guarded`** — `Model::create($request->all())` on a model lacking either property — define `$fillable` explicitly.
- **`$guarded = []`** — disables protection entirely; flag as `IMPORTANT` security risk.
- **`firstOrCreate` race condition** — without a unique constraint backing the lookup column, two requests can both insert.
- **`whereHas` heavy filter** — when the relation is small, `with` + collection filtering is cheaper.
- **`DB::raw` with user input** — SQL injection vector; switch to bindings or query-builder methods.
- **Missing return type on relationship method** — `public function posts()` should declare `: HasMany` (PHP 8+).
- **Accessor/mutator name mismatch** — `getFooAttribute` / `setFooAttribute` must match the column casing used by `$fillable`.
- **Soft-deleted records in queries** — explicit `withTrashed()` / `onlyTrashed()` is required when the intent is to include them; bare queries already exclude them.
- **`->get()` followed by `->count()`** — load-and-count is wasteful; use `->count()` directly on the builder.
- **Loop calling `->save()` per iteration** — switch to `->insert()` for bulk or `Model::upsert()` for idempotent batch.
- **Missing index on FK column in migration** — every `foreignId()` call should be followed by `->index()` or `->constrained()` (which adds the index implicitly).

## How to report

Severity heuristic:
- `IMPORTANT` for: `$guarded = []`, mass assignment of unvalidated input, `DB::raw` with user input, missing FK index on a hot column.
- `MINOR` for: style/efficiency issues like N+1 on small relations, missing return types.
```

**Step 2: Commit**

```bash
git add skills/laravel-eloquent/
git commit -m "feat: add laravel-eloquent pillar skill"
```

---

### Task 6: laravel-security skill

**Files:**
- Create: `skills/laravel-security/SKILL.md`

**Step 1: Write the skill**

```markdown
---
description: Laravel security checks — auth, validation, mass assignment, SQL injection, XSS, CSRF, secrets. Load when controllers, requests, auth, or routes change.
disable-model-invocation: true
---

# laravel-security

## When to load
Loaded when any of these change: `app/Http/Controllers/**`, `app/Http/Requests/**`, `app/Http/Middleware/**`, `routes/**`, `config/auth.php`, `app/Policies/**`, `resources/views/**` (for XSS), `.env*`.

## Rules

- **`$request->all()` passed to mass assignment** — accepts arbitrary fields; use `$request->validated()` after a `FormRequest`.
- **Missing `FormRequest` on state-changing route** — POST/PUT/PATCH/DELETE without dedicated request validation — `IMPORTANT`.
- **Authorization missing on a controller action** — no `$this->authorize()`, no policy check, no `auth.*` middleware on the route — `IMPORTANT`.
- **Raw SQL via `DB::raw` / `DB::statement` with user input** — SQL injection — `CRITICAL`. Use bindings.
- **`{!! $var !!}` in Blade with user input** — XSS — `IMPORTANT`. Use `{{ }}` or sanitize via `Purifier`/`HtmlString` only after explicit allow-listing.
- **`csrf_token` skipped on a state-changing route** — route excluded from `VerifyCsrfToken`'s `$except` should have a documented reason.
- **`Hash::make` / `Hash::check` replaced by `===` / `md5`** — `CRITICAL`. Always use `Hash::check`.
- **`.env` values committed or logged** — secrets in code or log lines — `CRITICAL`.
- **File upload without MIME validation** — `'file' => 'required|file'` is not enough; require `mimes:pdf,jpg,png` and a max size.
- **`Storage::url()` exposing private disk** — public URLs of files on the `private` disk leak data.
- **Disabled HTTPS in `APP_URL`** in non-local environments — flag `http://` outside `local`.
- **Open redirect** — `redirect($request->input('next'))` without allow-listing — `IMPORTANT`.
- **Missing rate limiting on auth/login routes** — should have `throttle:` middleware — `IMPORTANT`.
- **Token-bearing query strings logged** — passing tokens via `?token=` rather than headers logs them in webserver logs.
- **`auth()->loginUsingId()` from request input** — privilege escalation vector if input not strictly validated.

## How to report

Severity heuristic:
- `CRITICAL`: SQL injection, secret leak, hash/comparison broken, auth bypass.
- `IMPORTANT`: missing validation/authorization, XSS via `{!! !!}`, unrestricted file upload, missing rate limit.
- `MINOR`: HTTPS hygiene, defensive depth.
```

**Step 2: Commit**

```bash
git add skills/laravel-security/
git commit -m "feat: add laravel-security pillar skill"
```

---

### Task 7: laravel-performance skill

**Files:**
- Create: `skills/laravel-performance/SKILL.md`

**Step 1: Write the skill**

```markdown
---
description: Laravel performance checks — eager loading, indexing, queues, caching, chunking. Load when models, queries, jobs, or migrations change.
disable-model-invocation: true
---

# laravel-performance

## When to load
Loaded when any of these change: `app/Models/**`, `app/Jobs/**`, `app/Listeners/**`, `database/migrations/**`, files containing loops over query results, or any file with `->get()`/`->all()`/`->paginate()` near a loop.

## Rules

- **N+1 query in a loop** (cross-listed with eloquent) — every loop over a collection accessing a relation needs `->with('rel')` upstream.
- **`Model::all()` without pagination** on a table likely > 1000 rows.
- **`->count()` inside a loop** — moves to a single pre-loop count or a `withCount` on the parent query.
- **Missing index on foreign key in migration** — every `foreignId()` either uses `->constrained()` or pairs with `->index()`.
- **Missing index on common `where` columns** — columns named in `WHERE` clauses without indexes (heuristic: emit `MINOR` if a new query targets a column that has no index in the migrations changed in this PR).
- **Synchronous heavy work** — sending mail, hitting an external API, image processing — must be queued via `ShouldQueue`.
- **Queue job lacks `retryUntil`/`backoff`/`failed`** — flag jobs without retry policy as `MINOR`.
- **Cache misses on read-heavy endpoints** — controllers/services hitting the same heavy query on every request without `Cache::remember()`.
- **`Cache::forever`** — should expire; consider tags or TTL.
- **Eager loading too much** — `->with(['a','b','c','d'])` returning fields never used; suggest constrained eager loads or selecting only needed columns.
- **`->get()` then `->filter()` in PHP** — should be `->where()` in the builder.
- **String concatenation in tight loops** — minor; suggest `implode` or buffered output.

## How to report

Severity heuristic:
- `IMPORTANT`: N+1 on hot endpoint, missing FK index on a write-heavy table, sync heavy work in HTTP request path.
- `MINOR`: queue retry policy, cache miss patterns, over-eager loading.
```

**Step 2: Commit**

```bash
git add skills/laravel-performance/
git commit -m "feat: add laravel-performance pillar skill"
```

---

### Task 8: project-rules skill

**Files:**
- Create: `skills/project-rules/SKILL.md`

**Step 1: Write the skill**

```markdown
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
```

**Step 2: Commit**

```bash
git add skills/project-rules/
git commit -m "feat: add project-rules pillar skill"
```

---

## Phase 3 — Reviewer agent and slash command

### Task 9: tops-laravel-reviewer subagent

**Files:**
- Create: `agents/tops-laravel-reviewer.md`

**Step 1: Write the subagent definition**

````markdown
---
name: tops-laravel-reviewer
description: Reviews an open GitHub PR or GitLab MR for a Laravel project. Reads the locally-checked-out branch, runs Pint, evaluates the diff against pillar skills, and posts a single summary review comment. Invoked by the /tops-laravel:review slash command.
tools: Read, Grep, Glob, Bash, Write, mcp__gitlab__get_merge_request_details, mcp__gitlab__get_merge_request_changes, mcp__gitlab__list_merge_request_notes, mcp__gitlab__comment_on_merge_request, mcp__gitlab__get_project, mcp__gitlab__list_projects
---

You are the **tops-laravel-reviewer**. Your job is to review one open PR (GitHub) or MR (GitLab) and post a single summary comment.

## Inputs

You receive a single argument string from the slash command. It is one of:
- A bare integer like `123` → GitHub PR #123 in the current repo.
- An integer prefixed with `!` like `!456` → GitLab MR !456 in the current repo.
- A full URL → parse host + ref from the URL.
- Optionally followed by `--dry-run` → render the comment to stdout but do **not** post.

If the argument is missing or unparseable, print this usage block and stop:

```
Usage:
  /tops-laravel:review 123                  # GitHub PR
  /tops-laravel:review !456                 # GitLab MR
  /tops-laravel:review <full-url>
  /tops-laravel:review 123 --dry-run        # do not post
```

## Workflow

Execute these phases in order. Stop at the first hard failure unless noted.

### Phase A — Preflight

1. Confirm CWD is inside a git repo: `git rev-parse --is-inside-work-tree`. If not → fail with: `Run this command from inside the Laravel project root.`
2. Detect host:
   - GitHub: argument is `<int>`, or URL host matches `github.com`. Confirm `gh` is on PATH and `gh auth status` succeeds.
   - GitLab: argument starts with `!`, or URL host is anything else. Confirm the GitLab MCP tools are available.
3. Fetch PR/MR metadata:
   - GitHub: `gh pr view <n> --json headRefOid,headRefName,baseRefName,files,title,body,url`
   - GitLab: derive `project_id` via `mcp__gitlab__list_projects` (search by repo name) → call `mcp__gitlab__get_merge_request_details` and `mcp__gitlab__get_merge_request_changes`.
4. Compare local HEAD: `git rev-parse HEAD` must equal the PR/MR head SHA. If mismatch:
   - GitHub → fail with: `Checkout the PR branch first: gh pr checkout <n>`
   - GitLab → fail with: `Checkout the MR branch first: git fetch origin <head-ref> && git checkout <head-ref>`

### Phase B — Collect changed files

5. Build the changed-files list from the metadata. Filter to: `*.php`, `*.blade.php`, `composer.json`, `composer.lock` (presence only), `config/**`, `routes/**`, `database/migrations/**`, `database/seeders/**`. Exclude `vendor/**`, `node_modules/**`, `public/build/**`.
6. For each file, capture the unified diff (use `git diff <base>...HEAD -- <file>`) and the **full current content** (Read tool on the local file). The full content is necessary because findings often need surrounding context not in the diff.

### Phase C — Run Pint

7. If `./vendor/bin/pint` exists: run `./vendor/bin/pint --test <changed-php-files>` from the project root, capture stdout, exit code, and per-file violation lists.
8. If missing: skip Pint, remember to mention this in the comment summary.

### Phase D — Load relevant pillar skills

9. Always load: `laravel-best-practices`, `laravel-pint`, `project-rules`.
10. Load conditionally:
    - `laravel-eloquent` if any changed path matches `app/Models/**`, `app/Repositories/**`, `database/migrations/**`, or a changed file contains query-builder calls.
    - `laravel-security` if any changed path matches `app/Http/Controllers/**`, `app/Http/Requests/**`, `app/Http/Middleware/**`, `routes/**`, `app/Policies/**`, `resources/views/**`, or `config/auth.php`.
    - `laravel-performance` if any changed path matches `app/Models/**`, `app/Jobs/**`, `app/Listeners/**`, `database/migrations/**`, or contains loops over query results.

### Phase E — Analyze

11. For each loaded skill, walk its checklist against the diff + full file content. Emit findings as JSON entries with this schema (collected internally, not shown to the user):
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
12. De-duplicate: if two pillars produce the same finding, keep the higher-severity entry and merge categories with `+` (e.g. `Eloquent + Performance`).
13. Order: stable sort by `severity` (CRITICAL > IMPORTANT > MINOR), then by file path, then by line.

### Phase F — Compute verdict

14. Apply this rule:
    - any `CRITICAL` → `CHANGES REQUESTED`
    - else any `IMPORTANT` → `CHANGES REQUESTED`
    - else only `MINOR` → `APPROVED WITH SUGGESTIONS`
    - else 0 findings → `APPROVED`

### Phase G — Render markdown comment

15. Render this exact template (filling in the variables):

````markdown
## Automated Peer Review

**Verdict:** {VERDICT}
**Issues Found:** {N_CRITICAL} critical, {N_IMPORTANT} important, {N_MINOR} minor

### Summary
{1–3 paragraph plain-English overview: what the PR/MR does, what is correct, the most important issue framed by root cause. If no findings, state: "No issues found by the reviewer. The change adheres to all loaded pillars."}

### Issues

| # | Severity | Category | Description | File:Line |
|---|----------|----------|-------------|-----------|
{for each finding: | {id} | {SEVERITY} | {Category} | {description} | `{file}:{line}` |}

### Required Fixes Before Merge
{numbered list of remediation steps for every CRITICAL and IMPORTANT finding; for each, give the issue number, a short title, and concrete fix guidance (may include code blocks)}

---
_Generated by `tops-laravel-reviewer` · run locally · `{short-sha}` · `{iso-timestamp}`_
````

If `Pint: skipped` applies, append a single line at the end of the Summary section: `> Pint: skipped (./vendor/bin/pint not found — run \`composer install\`).`

If 0 findings: omit the **Issues** table and the **Required Fixes Before Merge** section; the Summary alone suffices.

### Phase H — Post or dry-run

16. Write the rendered markdown to `/tmp/tops-review-<host>-<n>.md`.
17. If `--dry-run`: print the file contents to stdout, then print a one-line summary: `Dry-run complete. {n} findings. Verdict: {VERDICT}.`
18. Otherwise post:
    - GitHub: `gh pr comment <n> --body-file /tmp/tops-review-github-<n>.md`
    - GitLab: `mcp__gitlab__comment_on_merge_request` with the rendered markdown as the body.
19. If the post fails: keep the `/tmp/...md` file and tell the user to paste it manually.

### Phase I — Terminal summary

20. Print to the terminal: a link to the posted comment (if posted), the verdict, and finding counts. Example:
    ```
    Posted: https://github.com/org/repo/pull/123#issuecomment-...
    Verdict: CHANGES REQUESTED
    Findings: 0 critical · 3 important · 4 minor
    ```

## Hard rules

- **Never modify the working tree.** No Edit tool. Write tool only writes to `/tmp/`.
- **Never invent files.** Only review files actually present in the changed-files list.
- **Never claim Pint passed for files Pint did not inspect.**
- **Never include `Co-Authored-By: Claude` (or any Claude/Anthropic) trailer** in the posted review comment.
- **Project rules outrank pillar rules.** If `CLAUDE.md` permits something a pillar forbids, the project rule wins.
- **Never review without the head SHA matching local HEAD.** Stale reviews mislead. Abort instead.
````

**Step 2: Verify the agent loads**

Run: `claude --plugin-dir /var/www/html/tops-laravel -p "/agents" 2>&1 | grep tops-laravel-reviewer`
Expected: agent name appears.

**Step 3: Commit**

```bash
git add agents/tops-laravel-reviewer.md
git commit -m "feat: add tops-laravel-reviewer subagent"
```

---

### Task 10: review slash command

**Files:**
- Create: `commands/review.md`

**Step 1: Write the slash command**

```markdown
---
description: Review an open GitHub PR or GitLab MR. Usage: /tops-laravel:review <pr-number|mr-bang|url> [--dry-run]
---

Run a Laravel-aware code review on the open PR/MR identified by `$ARGUMENTS`.

Dispatch to the **tops-laravel-reviewer** subagent (defined in this plugin) with the argument string verbatim. Forward all of its output (markdown comment + terminal summary) back to me without modification.

If `$ARGUMENTS` is empty, ask the agent to print its usage block and stop.
```

**Step 2: Smoke test (no PR needed)**

Run: `claude --plugin-dir /var/www/html/tops-laravel -p "/tops-laravel:review" 2>&1 | head -20`
Expected: usage block is printed (no integer was provided).

**Step 3: Commit**

```bash
git add commands/review.md
git commit -m "feat: add /tops-laravel:review slash command"
```

---

## Phase 4 — Test harness and fixtures

### Task 11: Clean fixture (no findings expected)

**Files:**
- Create: `tests/fixtures/clean/app/Http/Controllers/UserController.php`
- Create: `tests/fixtures/clean/app/Http/Requests/StoreUserRequest.php`
- Create: `tests/fixtures/clean/app/Models/User.php`
- Create: `tests/fixtures/clean/expected.json`
- Create: `tests/fixtures/clean/diff.patch`

**Step 1: Write a clean controller**

`tests/fixtures/clean/app/Http/Controllers/UserController.php`:
```php
<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreUserRequest;
use App\Models\User;
use Illuminate\Http\JsonResponse;

final class UserController extends Controller
{
    public function store(StoreUserRequest $request): JsonResponse
    {
        $user = User::create($request->validated());

        return response()->json($user, 201);
    }
}
```

**Step 2: Write a clean FormRequest**

`tests/fixtures/clean/app/Http/Requests/StoreUserRequest.php`:
```php
<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

final class StoreUserRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', \App\Models\User::class);
    }

    public function rules(): array
    {
        return [
            'name'  => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'unique:users,email'],
        ];
    }
}
```

**Step 3: Write a clean model**

`tests/fixtures/clean/app/Models/User.php`:
```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

final class User extends Model
{
    use HasFactory;

    protected $fillable = ['name', 'email'];

    public function posts(): HasMany
    {
        return $this->hasMany(Post::class);
    }
}
```

**Step 4: Write `expected.json`**

```json
{
  "verdict": "APPROVED",
  "min_critical": 0,
  "max_critical": 0,
  "min_important": 0,
  "max_important": 0,
  "min_minor": 0,
  "max_minor": 1,
  "must_contain_substrings": [],
  "must_not_contain_substrings": ["CHANGES REQUESTED", "CRITICAL"]
}
```

**Step 5: Write `diff.patch`** — a synthetic diff that adds the three files. The harness will use this when no real PR is available; for the first cut, leave the file as a placeholder note: `# fixture is full-file; harness reviews all .php files in this directory`.

```
# fixture is full-file; harness reviews all .php files in this directory
```

**Step 6: Commit**

```bash
git add tests/fixtures/clean/
git commit -m "test: add clean Laravel fixture for reviewer harness"
```

---

### Task 12: Dirty fixture (planted findings)

**Files:**
- Create: `tests/fixtures/dirty/app/Http/Controllers/PostController.php`
- Create: `tests/fixtures/dirty/app/Models/Post.php`
- Create: `tests/fixtures/dirty/database/migrations/2026_04_28_000000_create_posts_table.php`
- Create: `tests/fixtures/dirty/CLAUDE.md`
- Create: `tests/fixtures/dirty/expected.json`

**Step 1: Write a controller with planted issues** (mass-assignment, N+1, raw SQL, missing FormRequest, project-rule violation)

`tests/fixtures/dirty/app/Http/Controllers/PostController.php`:
```php
<?php

namespace App\Http\Controllers;

use App\Models\Post;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class PostController extends Controller
{
    public function index(Request $request)
    {
        $posts = Post::all();
        foreach ($posts as $post) {
            $post->author->name;
        }

        return $posts;
    }

    public function store(Request $request)
    {
        Log::info('Creating post: ' . $request->title);

        $sql = "SELECT * FROM users WHERE name = '" . $request->input('author') . "'";
        $author = DB::select($sql);

        return Post::create($request->all());
    }
}
```

Planted findings:
- N+1 in `index()` → eloquent + performance.
- `Post::all()` without pagination → performance.
- `Log::info` in production controller → project-rule violation (see fixture's CLAUDE.md).
- Raw SQL with concat → security CRITICAL.
- `Request` instead of `FormRequest` for `store()` → security IMPORTANT.
- `$request->all()` mass assign → security IMPORTANT.
- Class not `final` → minor (best-practices).

**Step 2: Write a model with planted issues**

`tests/fixtures/dirty/app/Models/Post.php`:
```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Post extends Model
{
    protected $guarded = [];

    public function author()
    {
        return $this->belongsTo(User::class, 'author_id');
    }
}
```

Planted findings:
- `$guarded = []` → eloquent IMPORTANT.
- Missing return type on `author()` → eloquent MINOR.

**Step 3: Write a migration with a planted issue**

`tests/fixtures/dirty/database/migrations/2026_04_28_000000_create_posts_table.php`:
```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('posts', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('author_id');
            $table->string('title');
            $table->timestamps();
        });
    }
};
```

Planted findings:
- `unsignedBigInteger('author_id')` without `->index()` or `->constrained()` → performance MINOR.
- Missing `down()` method → project-rule violation (see fixture CLAUDE.md).

**Step 4: Write the fixture's `CLAUDE.md`**

```markdown
# Project rules

- Never use `Log::info()` in production controllers — use exception tracking instead.
- Migrations must always include a `down()` rollback method.
```

**Step 5: Write `expected.json`**

```json
{
  "verdict": "CHANGES REQUESTED",
  "min_critical": 1,
  "max_critical": 2,
  "min_important": 4,
  "max_important": 8,
  "min_minor": 2,
  "max_minor": 8,
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

(The harness treats each `must_contain_substrings` entry as an OR-pattern split on `|`.)

**Step 6: Commit**

```bash
git add tests/fixtures/dirty/
git commit -m "test: add dirty Laravel fixture with planted findings"
```

---

### Task 13: Test harness script

**Files:**
- Create: `tests/run-tests.sh`
- Modify: `agents/tops-laravel-reviewer.md` to support a synthetic mode (see step 3).

**Step 1: Add a synthetic-mode hook to the agent**

In `agents/tops-laravel-reviewer.md`, append a new section near the top of the **Workflow** area (between Phase A and Phase B). Old text:

```
### Phase B — Collect changed files
```

New text (insert before that heading):

```
### Phase A.5 — Synthetic fixture mode

If the argument starts with `fixture:` (e.g. `fixture:clean` or `fixture:dirty`), skip Phase A entirely and instead:

- Treat the directory `tests/fixtures/<name>/` (relative to plugin root) as the project root for the rest of the review.
- Treat every `.php` file under that directory as "changed".
- Skip Phase H entirely (do not post). Always behave as if `--dry-run` is set.
- After rendering the markdown comment to stdout, also print a one-line JSON summary on its own line:
  `__FIXTURE_RESULT__ {"verdict":"...","critical":N,"important":N,"minor":N}`

This mode exists solely for the test harness; it is never used in real reviews.

```

**Step 2: Write `tests/run-tests.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES=("clean" "dirty")
FAIL=0

for name in "${FIXTURES[@]}"; do
    expected="$PLUGIN_DIR/tests/fixtures/$name/expected.json"
    if [[ ! -f "$expected" ]]; then
        echo "[$name] SKIP — no expected.json"
        continue
    fi

    echo "[$name] running reviewer..."
    out="$(claude --plugin-dir "$PLUGIN_DIR" -p "/tops-laravel:review fixture:$name" 2>&1)"

    result_line="$(echo "$out" | grep '^__FIXTURE_RESULT__' | tail -1 | sed 's/^__FIXTURE_RESULT__ //')"
    if [[ -z "$result_line" ]]; then
        echo "[$name] FAIL — no __FIXTURE_RESULT__ line in output"
        echo "$out" | tail -40
        FAIL=1; continue
    fi

    verdict="$(echo "$result_line" | jq -r '.verdict')"
    critical="$(echo "$result_line" | jq -r '.critical')"
    important="$(echo "$result_line" | jq -r '.important')"
    minor="$(echo "$result_line" | jq -r '.minor')"

    exp_verdict="$(jq -r '.verdict' "$expected")"
    min_c="$(jq -r '.min_critical' "$expected")"; max_c="$(jq -r '.max_critical' "$expected")"
    min_i="$(jq -r '.min_important' "$expected")"; max_i="$(jq -r '.max_important' "$expected")"
    min_m="$(jq -r '.min_minor' "$expected")"; max_m="$(jq -r '.max_minor' "$expected")"

    pass=1
    [[ "$verdict" == "$exp_verdict" ]] || { echo "[$name] verdict mismatch: got $verdict, want $exp_verdict"; pass=0; }
    (( critical >= min_c && critical <= max_c )) || { echo "[$name] critical=$critical not in [$min_c,$max_c]"; pass=0; }
    (( important >= min_i && important <= max_i )) || { echo "[$name] important=$important not in [$min_i,$max_i]"; pass=0; }
    (( minor >= min_m && minor <= max_m )) || { echo "[$name] minor=$minor not in [$min_m,$max_m]"; pass=0; }

    while IFS= read -r needle; do
        [[ -z "$needle" ]] && continue
        match=0
        IFS='|' read -ra alts <<< "$needle"
        for a in "${alts[@]}"; do
            grep -qF -- "$a" <<< "$out" && { match=1; break; }
        done
        (( match )) || { echo "[$name] missing required substring (any of): $needle"; pass=0; }
    done < <(jq -r '.must_contain_substrings[]' "$expected")

    while IFS= read -r needle; do
        [[ -z "$needle" ]] && continue
        if grep -qF -- "$needle" <<< "$out"; then
            echo "[$name] forbidden substring present: $needle"; pass=0
        fi
    done < <(jq -r '.must_not_contain_substrings[]' "$expected")

    (( pass )) && echo "[$name] PASS" || { echo "[$name] FAIL"; FAIL=1; }
done

exit "$FAIL"
```

**Step 3: Make it executable**

```bash
chmod +x tests/run-tests.sh
```

**Step 4: Run the harness**

```bash
./tests/run-tests.sh
```

Expected: `[clean] PASS` and `[dirty] PASS`. If either fails, iterate on the relevant skill prompt or the agent workflow until both pass. **Do not loosen `expected.json` to make tests pass — fix the prompts.**

**Step 5: Commit**

```bash
git add tests/run-tests.sh agents/tops-laravel-reviewer.md
git commit -m "test: add fixture-based reviewer harness with synthetic mode"
```

---

## Phase 5 — Real-world smoke test

### Task 14: Smoke test on a real GitHub PR

**Files:** none (manual test).

**Step 1:** Pick (or create) a small PR in any internal Tops Laravel repo on GitHub. Check it out: `gh pr checkout <n>` from the project root.

**Step 2:** Run the reviewer in dry-run mode first:

```bash
claude --plugin-dir /var/www/html/tops-laravel -p "/tops-laravel:review <n> --dry-run"
```

Verify: comment renders, no errors, verdict matches your expectation, file:line references resolve.

**Step 3:** Run for real (posts the comment):

```bash
claude --plugin-dir /var/www/html/tops-laravel -p "/tops-laravel:review <n>"
```

Verify on github.com that the comment posted, formatting is intact, the table renders, the verdict line matches, and the trailer line at the bottom contains the short SHA + timestamp (and **no** `Co-Authored-By` line).

**Step 4:** If anything is off, iterate on `agents/tops-laravel-reviewer.md` and re-run the dry-run until correct, then post once more.

**Step 5:** No commit required unless agent prompt changed. If changed:

```bash
git add agents/tops-laravel-reviewer.md
git commit -m "fix: <what was wrong>"
```

---

### Task 15: Smoke test on a real GitLab MR

**Files:** none (manual test).

**Step 1:** Pick (or create) a small MR in an internal Tops Laravel repo on `git.topsdemo.in`. Check out the MR branch locally.

**Step 2:** Confirm the GitLab MCP is authenticated for that host. Run a probe (an Anthropic-style smoke check):

```bash
claude --plugin-dir /var/www/html/tops-laravel -p "use mcp__gitlab__list_projects with search 'power-outage'" | head
```

Expect a non-401 response. If 401, fix MCP auth before continuing.

**Step 3:** Run the reviewer dry-run:

```bash
claude --plugin-dir /var/www/html/tops-laravel -p "/tops-laravel:review !<n> --dry-run"
```

**Step 4:** Run for real:

```bash
claude --plugin-dir /var/www/html/tops-laravel -p "/tops-laravel:review !<n>"
```

Verify the MR comment on GitLab.

**Step 5:** Commit any fix-up changes.

---

## Phase 6 — Release

### Task 16: Tag v1.0.0 and update README distribution section

**Files:**
- Modify: `.claude-plugin/plugin.json` (bump `version` to `1.0.0`)
- Modify: `README.md` (add an "Install for the team" section)

**Step 1: Bump version**

In `.claude-plugin/plugin.json`, change `"version": "0.1.0"` to `"version": "1.0.0"`.

**Step 2: Append to README**

```markdown
## Install for the team

Once published to the Tops org-internal Claude Code marketplace:

```bash
/plugin marketplace add <git-url-of-marketplace-repo>
/plugin install tops-laravel
```

Update later with `/plugin update tops-laravel`.
```

**Step 3: Commit and tag**

```bash
git add .claude-plugin/plugin.json README.md
git commit -m "release: tops-laravel v1.0.0"
git tag v1.0.0
```

**Step 4:** Push to the org-internal git repo (out of scope of this plan; whoever runs this task knows the repo URL).

---

## Definition of done for v1

- [ ] `claude --plugin-dir /var/www/html/tops-laravel` loads without errors and `/tops-laravel:review` shows up in `/help`.
- [ ] `tests/run-tests.sh` passes both fixtures.
- [ ] Smoke test on a real GitHub PR posts a correctly-formatted comment with no `Co-Authored-By` trailer.
- [ ] Smoke test on a real GitLab MR posts a correctly-formatted comment with no `Co-Authored-By` trailer.
- [ ] `v1.0.0` tagged in git.
- [ ] All commits land on `main`; commit history reads as a clean changelog.
