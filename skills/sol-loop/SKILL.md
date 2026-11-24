---
name: sol-loop
description: Reviews the current change with GPT Sol in a short fix loop. Use only when the user says "sol loop"; never start it on your own.
---

# sol-loop

Have GPT Sol review your change in a loop, before (or sometimes after) filing
a PR. Make the smallest changes that satisfy Sol; resist scope creep and push
back when warranted.

## Budget

- Default 3 rounds. Round 1 is full; later rounds check only changed code and
  open findings.
- Extend to 5 only for security, permissions, auth, data loss, or
  state/concurrency while a blocker or should stays open with evidence, or
  when the user asks.
- Stop early if a round returns only nits. Declined nits and comment-, doc-,
  or format-only fixes need no new round.
- One reviewer only. Sol must not start subagents or reviewers.
- Keep a ledger: id, severity, outcome, usage if returned. Never guess it.

## 1. Scope

Run `git status --short`. Don't stash, discard, or include unrelated changes.
Limit review to the change paths if they separate cleanly; otherwise stop and
ask.

Find the base after `git fetch origin`:

- PR: `gh pr view <n> --json baseRefName,headRefOid`. Check out the branch
  only if clean. Confirm `HEAD` is the PR head, or ahead only by this change.
  Base: `git merge-base HEAD origin/<baseRefName>`.
- Local: `git merge-base HEAD origin/<default-branch>`. No remote: a base the
  user names, or `HEAD` for uncommitted changes only.

The change is base to working tree in those paths, with untracked files; use
one diff command all rounds. State intent and out-of-scope in 1-2 sentences.
Run covering checks; don't send code this change breaks. Note missing or
pre-failing checks in the brief.

## 2. Start Sol

T3: call `orchestrator_capabilities`; pick the latest Sol unless the user
named a version; don't hardcode an ID. Record provider, model, and effort only
if exposed. Every round: `delegate_task` (`role: "review"`, `mode: "async"`),
save `taskId`, new `clientRequestId`. `childThreadId` is storage, not the next
target. Don't use `t3_thread_send`, `create_threads`, or `t3_thread_launch`
for review.

If T3 tools aren't listed, try one direct capability call. Outside T3, use a
native Sol subagent and keep its ID; in Claude Code, a custom subagent only if
it's set up to run Sol. If no route runs Sol, report the blocker; don't
substitute a model.

While review runs, don't edit scoped files, poll, or start a second reviewer;
wait for the notice. Timeout, error, or no reply is not approval. On failure:
cancel, verify it stopped, restart with the ledger.

Round 1 brief (T3 children get no history):

```
Review only. Do not edit, commit, push, comment on PRs, or start subagents.
Repo: <abs path> Base: <sha> Intent: <intent> Out of scope: <scope> Checks: <results>
See: git diff <base> [-- <paths>]; git status --short (read untracked).
Read surrounding code. Find bugs, broken callers, mismatch with intent.
Skip style unless it hides a bug. Hold to the smallest change. Flag code,
tests, or guards the intent does not need. Other paths, rare cases, small
perf, extra compat: nits.
blocker = intended case wrong. should = real bug callers will hit, in intent. nit = rest.
Reply:
VERDICT: APPROVE or CHANGES
S1 [blocker|should|nit] <file>:<line> <claim>. Fix: <suggestion> (stable ids)
```

## 3. Answer findings

Check each finding and severity yourself. Another path, rare case, or small
cost is a nit, whatever its label.

- Agree: smallest fix. Prefer delete or narrow over a new lock, cache, helper,
  or option. Fix the case that happened. Add one focused test that fails
  without the fix, if the intent needs it.
- Disagree: say why, with evidence (file:line, test, output).
- Out of scope or nit: decline in one line; list as follow-up.

Update the ledger. Re-run checks and `git diff --shortstat <base>`; if review
grew the diff, cut first. Don't agree just to end the loop.

## 4. Next round

Only if budget remains and a blocker or should is open, behavior code changed,
or approval doesn't cover the current behavior diff. Fresh `delegate_task` in
T3, or follow up the saved native ID. Send the round 1 brief, the ledger
(`fixed:` / `disagree:` / `declined:` + evidence), the same base diff, and the
change since last round. Tell Sol: open ids and changed code only; mark each
old id `resolved` or `still open: <reason>`.

## 5. Stop and ship

Agreed: APPROVE on the current behavior diff, no blocker or should open, no
concern of your own. Stuck: an item stays disputed after two replies, or
budget ends; show both sides in 2-3 lines each and let the user decide. Budget
end is not approval.

Don't push during the loop. After agreement, push only if the user asked to
push, ship, or update the PR. If you push to a PR, add above the model blurb:

`Reviewed with sol-loop: <N> rounds with <model>. Sol verdict: approved`.

Add `on <effort>` only if verified.

Report: rounds, model, what Sol changed, diff size before/after, fixed and
declined findings with reasons, usage if exposed (else say not), pushed or
not.
