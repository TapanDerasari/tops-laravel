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
