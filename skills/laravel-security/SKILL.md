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
