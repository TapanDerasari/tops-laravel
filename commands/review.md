---
description: Review an open GitHub PR or GitLab MR. Usage: /tops-laravel:review <pr-number|mr-bang|url> [--dry-run]
---

Run a Laravel-aware code review on the open PR/MR identified by `$ARGUMENTS`.

Dispatch to the **tops-laravel-reviewer** subagent (defined in this plugin) with the argument string verbatim. Forward all of its output (markdown comment + terminal summary) back to me without modification.

If `$ARGUMENTS` is empty, ask the agent to print its usage block and stop.
