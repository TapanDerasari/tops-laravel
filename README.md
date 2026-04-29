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

## Install for the team

This repo is its own Claude Code marketplace. Each team member needs to run
two commands once to get started:

### Step 1 — Register the marketplace

```text
/plugin marketplace add TapanDerasari/tops-laravel
```

### Step 2 — Install the plugin

```text
/plugin install tops-laravel@tops-laravel
```

That's it — the `/tops-laravel:review` command is now available in your Claude
Code sessions.

### Staying up to date

When the author publishes new changes (rules, skills, or bug fixes) to this
repo, they are **not** pushed to your machine automatically. You pull updates
on your own schedule:

```text
/plugin marketplace update tops-laravel
```

Run this whenever you want the latest version. New rules and features take
effect immediately in your current session.

### Auto-enable for an entire project (recommended for teams)

Instead of asking every teammate to install manually, you can wire the plugin
into a specific Laravel project. Add the following to that project's
`.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "tops-laravel": {
      "source": { "source": "github", "repo": "TapanDerasari/tops-laravel" }
    }
  },
  "enabledPlugins": { "tops-laravel@tops-laravel": true }
}
```

Once this is committed, anyone on the team who opens the project in Claude Code
will have the plugin available automatically — no manual install steps needed.
They still control when to pull newer versions via the update command above.
