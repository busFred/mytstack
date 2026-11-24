---
name: babysit-pr
description: Watches a PR through CI and review bots, fixing real findings until it is ready. Use when the user asks to monitor, watch, or babysit a PR.
---

# Babysit PR

## Waiting

Never write your own watcher, polling loop, or `sleep` loop. One watcher per
PR: `watch_pull_request` in T3 Code, `pr-wait` everywhere else; never both on
the same PR. All watchers on a GitHub account share one rate limit.

### T3 Code: `watch_pull_request`

Handle existing checks and comments first, then call `watch_pull_request` and
end your turn. T3 Code wakes you when a check fails, required checks pass,
someone comments or reviews, or the branch conflicts.

- **Only the thread that owns the PR watches it.** A delegated child (a
  reviewer, a Sol round, any `delegate_task` child) never calls
  `watch_pull_request`; the parent owns the PR. Don't watch PRs you aren't
  working on.
- **A wake is news, not a merge decision.** Check the merge gate yourself.
- **Unwatch when you hand off.** A watched thread stays in Working, out of the
  user's inbox. Before you stop (ready, blocked, or asking the user), call
  `unwatch_pull_request`. A merge or close ends the watch on its own.
- **"Stopped watching, could not read it"** usually means GitHub's rate limit
  is used up. Run `gh api rate_limit --jq .resources.graphql` before watching
  again. If `remaining` is near 0, wait for `reset` with one background
  command, then watch again; never re-watch in a tight loop.

### Elsewhere: `pr-wait`

Run `scripts/pr-wait` from this skill's directory, by absolute path:

```bash
pr-wait <pr> [--repo owner/name] [--until ready|green|any-change]
```

Prints one line per real event. Exits 0 when the `--until` condition is met
or the PR merges; 1 when it needs you (required check failed, conflicts,
unresolved threads, PR closed); 2 on bad input.

- `ready` (default): required checks green, Greptile or Macroscope reviewed
  the head, no unresolved threads. Use this to babysit.
- `green`: required checks only, for repos without Greptile or Macroscope.
- `any-change`: exit on the first event.

In Claude Code, run it with the Monitor tool (`timeout_ms: 3600000`) so each
line wakes you; without a monitor, as one long command (it ends on its own).

Restart it after you push, after handling an exit 1, and after a resume; it
remembers what it reported, so nothing in between is lost. If it says another
pid already watches the PR, don't start a second; kill the old one only if its
events don't reach you.

Either watcher: when an event needs no action, end your turn without a
message. Never post or say "still waiting".

## GitHub rate limits

`gh pr create`, `gh pr view`, and `gh pr checks` use GraphQL. When GraphQL is
used up, the separate REST limit usually has room: read a PR with
`gh api repos/<owner>/<repo>/pulls/<n>`, checks with
`gh api repos/<owner>/<repo>/commits/<sha>/check-runs`.

## Reviews

- Act only on checks and comments newer than the latest push.
- AI review bots help but aren't always right: verify every bot finding
  against the source before changing code.
- Fix real findings and CI failures; tell repository failures from
  infrastructure flakes.
- Dismiss false positives with a written reason. Bot feedback not worth
  addressing: reply with a written reason and resolve the comment. Use
  `leaving-pr-comments` for every comment posted on the user's behalf.
- If the repo has `.macroscope/check-run-agents/*.md`, read those rules before
  replying to a Macroscope finding; its findings cite them.
- CodeRabbit is advisory: treat its findings like any other, but never wait
  for it or hold a merge for it.
- Screenshots and videos help, when you can upload them.

Keep the PR at the size the user's goal needs; review loops grow PRs one
cheap-looking fix at a time. Fix real bugs in the intended case. Decline the
rest with a written reason and list them as follow-ups: unneeded tests, guards
for edge cases that don't matter, extra integration or compatibility, small
performance costs. Prefer the fix that deletes or narrows code.

## Base branch and merging

Track changes to `main` and rebase when needed. `pr-wait` reports new base commits that
touch this PR's files, and the PR becoming BEHIND or DIRTY.
`watch_pull_request` reports conflicts only, so check BEHIND yourself before
calling the PR ready.

If an overlapping PR makes this one obsolete, stop monitoring, report it to the
user, and ask before closing the PR unless closure was explicitly authorized.

If nothing changed, stay quiet; no filler comments. Stop when `pr-wait` exits
0, or in T3 Code when the merge gate passes on the latest head. Merge only if
the user explicitly asked; otherwise report the PR ready. Right before a
merge, `git fetch` and recheck the PR. Never merge when it's BEHIND or DIRTY,
or when base commits that landed after the last green run touch this PR's
files: rebase, push, and wait for green again.
