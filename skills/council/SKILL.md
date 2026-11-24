---
name: council
description: Runs a scored review panel of three models from three providers. Use only when the user says 'council'; never start it on your own.
---

# Council

First address outstanding PR comments, fix known issues, and run relevant
checks, so the council gets the updated implementation; don't defer known
fixes until reviews return. If the user is discarding the implementation to
explore new ideas, skip fixes to code being replaced.

## Members

Three delegates (usually for review or feedback): one strong model from each
of three different providers, high reasoning effort. Use members the user's
instructions name; else each provider's latest flagship (e.g. Claude Opus,
GPT Sol, Gemini Pro).

- T3 Code: resolve models with `orchestrator_capabilities`, then one
  `delegate_task` per model, in parallel. Elsewhere: the harness's subagent
  tools.
- Three providers unreachable, or a named member unavailable: report it,
  don't substitute.
- Give each the request and relevant context. Review or feedback stays
  read-only.

## While they run

- Don't wait idle: check each result against the code on arrival and decide
  fixes while the others run.
- No file edits while a delegate still reviews the same checkout.
- Delegate the user's instructions mark non-blocking: don't wait for it; a
  late result is feedback, its score not recorded.
- Summarize useful findings, disagreements, and recommended next steps.

## Scores and rounds

Code review: each delegate scores out of 10. A full review pass is one round;
a fresh review after fixes starts a new round.

If the work ends in a pull request, add this section to the PR description,
before the model and harness line at the end:

```markdown
## Council review

Rounds: 2

| Delegate | Round 1 | Round 2 |
| --- | --- | --- |
| Claude Opus | 7/10 | 9/10 |
| GPT Sol | 8/10 | 10/10 |
| Gemini Pro | 7/10 | 9/10 |
```

- No score: write `no score`; never invent one.
- Open PR: edit the description; no comment for this.
- No PR: the same results in the final reply only.

## Iterate

Make the changes you agree with, request a fresh review, repeat until all
delegates are satisfied. Fight scope creep across rounds; keep scope limited.
