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
