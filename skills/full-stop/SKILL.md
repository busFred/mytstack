---
name: full-stop
description: Runs full-send unattended but stops with the PR ready, never merging. Use only when the user says 'full stop', even as a closing "Full stop." that reads like emphasis.
---

# Full Stop

Same work as `full-send`, but stop with the PR ready for the user to merge.
Never merge it.

Read [full-send](../full-send/SKILL.md) and follow its workflow, proof rules,
review, and babysitting. An explicit "full stop" authorizes that work without
a separate "full send", including full-send's testing permission: use the
test methods Proof needs directly, even where a project file says to ask
first (e.g. before computer use). Its merge permission does not apply. The
overrides below take precedence.

## No merging

On this task's branch you may commit, push, rebase, fix conflicts, and use
`--force-with-lease`. Never merge, enable auto-merge, enter a merge queue,
push to the default branch, bypass branch protection, or delegate those.

Before work begins, disable existing auto-merge and remove the PR from any
merge queue; recheck before each push; report these changes. If you can't
prevent automatic merging, report the blocker before proceeding.

## Stop at the gate

Full-send's merge gate is the readiness check; a handoff replaces its merge
and final report steps. Proof and review cover the final diff; recheck
behavior changes and meaningful conflict fixes before handoff.

Fetch the target branch; check the live PR's head, base, checks, reviews,
mergeability. Confirm it's open, not a draft, not set to merge without the
user. If someone else merged it, report that instead.

- **Ready to merge:** gate passes. Leave the PR open and unmerged.
- **Waiting for required approval:** only human approval remains; confirm
  it's the actual blocker.
- **Blocked:** what prevents readiness, what you tried, what's needed.
  Follow full-send's rules for asking the user.

In T3 Code, call `unwatch_pull_request` before the handoff or a question.
Report PR link, final head, verdict, proof, reviewer outcome, remaining
risks, and whether the PR is still open and unmerged.
