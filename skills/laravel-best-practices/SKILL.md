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
