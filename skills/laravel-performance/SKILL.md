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
