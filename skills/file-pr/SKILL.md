---
name: file-pr
description: Files a concise PR with a why-focused title and a problem-first description. Use when the user asks to file, open, or create a PR.
---

# File PR

Check whether a PR for this branch already exists. Review the diff locally
against the base (usually `origin/main`) to confirm it matches the goal.

**Title.** PR titles usually become commit messages: follow the repo's title
conventions (see recently merged PRs and Git history). Prefer a concise,
human-readable title that says why the change matters:

> ❌ perf(server): negotiate permessage-deflate on the websocket

> ✅ perf(server): cut websocket frame size by 70%+ with gzipping

**Description.** Open with a simple explanation of the problem, based on the
user's original prompt, then briefly the solution. Don't lead with an
implementation inventory:

> ❌ Removed implicit workspace carry-over from every "new thread" entry point (cmd+n / cmd+shift+o, sidebar v1/v2 buttons, command palette). New threads inherit only the project from context; branch, worktree, and env mode always come from the configured defaults. Deleted buildContextualThreadOptions, startNewThreadInProjectFromContext, and the v1 sidebar's seed-context machinery.

> ✅ My "new worktree" default was ignored when starting new threads on existing worktrees. Super unintuitive. Now your preferences always apply.

End the description with the public model name and harness that made the changes, e.g.
`Created with <model> in <harness>.` Include subagent models that wrote part
of the change. Use the model name the harness reports; if unavailable, name
the harness without guessing a model.

Before submitting, check the title, description, quotes, and attachments for
secrets and private details.

Open a real PR, not a draft, so review bots run. If `gh pr create` fails
because the GraphQL rate limit is used up, use REST:
`gh api repos/<owner>/<repo>/pulls -f title=... -f head=... -f base=... -F body=@<file>`.
If the user also asked to babysit it, continue with `babysit-pr`.

Post a follow-up PR comment only if it serves the user's request, using
`leaving-pr-comments`.
