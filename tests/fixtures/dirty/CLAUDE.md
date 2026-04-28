# Project rules

- Never use `Log::info()` in production controllers — use exception tracking instead.
- Migrations must always include a `down()` rollback method.
