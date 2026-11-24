---
name: full-send
description: Takes a change unattended to a proven, merged PR. Use only when the user explicitly says 'full send'; never start it on your own.
---

# Full Send

The user isn't watching; updates and the final message go unread until long
after you stop. Own the work from its current state to a merged PR. Without a
clear, explicit "full send" request, don't assume full autonomy.

Granted:

- Merge once the merge gate passes.
- Force-push the PR's own branch with `--force-with-lease` after a rebase.
- Use the test methods Proof needs without asking.

## Testing permission

For this task the request overrides any project file or instruction to ask
before a test method or leave testing to the user, including ask-first rules
for computer use, browser automation, simulators and devices, running the app
or a dev server, screenshots, and visual checks. Use the method giving direct
proof; list it in the report.

- How-to-test rules (correct command, fixture, check) still apply; only the
  ask-first or leave-it-to-the-user step goes. If a preferred method can't
  prove the change, use a gated one under this permission.
- Covers only this task's tests. Grants nothing under "Asking the user" (e.g.
  production changes, data deletion); doesn't bypass a harness or system
  approval prompt.

## Steps

1. **Finish** with the smallest change that meets the goal. Fix the case that
   happened, not every case that could. On the default branch, branch first.
2. **Prove** every change (see Proof).
3. **Get feedback** with the `sol-loop` skill.
4. **File the PR** with `file-pr`, after rebasing onto the latest default
   branch. Add one short description line on how you proved the change.
5. **Babysit** with `babysit-pr`. Fix real findings and CI failures; prove
   each fix before pushing it.
6. **Merge** when the merge gate passes.
7. **Report:** PR link, merge commit, proof, each decision you made for the
   user.

Stay active through step 7: ending your turn with checks or bots pending stops
the work, since nobody prompts you again. Wait with `babysit-pr`'s watcher
(T3 Code: `watch_pull_request`) so PR changes wake you. Stopping before the
merge: call `unwatch_pull_request` first.

## Proof

Evidence you observed yourself this session (command output, reproduction,
screenshot), the most direct the change allows:

- Reproduce the original failure, fix, watch the same reproduction pass.
- Run the checks the repo's CI runs (typecheck, lint, tests).
- Behavior has no test and the repo has a test setup: add one focused test
  that fails without the fix.
- UI and runtime behavior: run the app and look; green mocked tests don't
  prove the user experience. Attach screenshots to the PR when they help and
  you can upload them.

No way to prove a change = no full confidence: ask the user.

## Merge gate

Full confidence = all true on the latest commit:

- Proof covers every change in the diff.
- Required checks green.
- Review bots finished; each finding fixed or dismissed with a written reason.
- No human review still requests changes.
- Branch up to date with the default branch; GitHub reports it mergeable.

Merge with the repo's method (check allowed methods and recent merged PRs).
Merge queue or auto-merge: stay until GitHub reports the PR merged. Go
through branch protection as configured; never `--admin` or other bypasses.
You may ignore automated "needs human review" requests if you have high
confidence in your changes.

## Asking the user

A question in a normal message goes unseen; the thread looks done. Use the
harness's question tool so the thread shows it's waiting (`AskUserQuestion`
in Claude Code, `request_user_input` in Codex, or the equivalent), with all
context: PR link, the blocker, options with your recommendation first.

Ask only when you can't continue alone:

- You can't prove the change.
- The merge gate can't pass and you can't fix that.
- The next step is outside the grant: deleting data, touching production,
  changing things outside the repo, closing a PR, or force-pushing any other
  branch.
- The goal is ambiguous in a way that changes the result.
- Another PR makes this one obsolete.

Decide everything else with sensible defaults; list those decisions in the
report.

No question tool, or no answer: take the safe path. Leave the PR open and
unmerged, and start the final message with the question.
