---
name: council
description: Runs a scored review panel of three models from three providers, or a read-only investigation of a root cause or a design choice. Use when the user says 'council', or when the user's instructions or another skill call for one; never start one otherwise.
---

# Council

For reviews of code, first address outstanding PR comments, fix known issues,
and run relevant checks, so the council gets the updated implementation;
don't defer known fixes until reviews return. If the user is discarding the
implementation to explore new ideas, skip fixes to code being replaced.

## Members

Three delegates (usually for review or feedback): one strong model from each
of three different providers, high reasoning effort. Use members the user's
instructions name; else each provider's latest flagship (e.g. Claude Opus,
GPT Sol, Gemini Pro).

- T3 Code: resolve models with `orchestrator_capabilities`, then one
  `delegate_task` per model, in parallel. Elsewhere: the harness's subagent
  tools.
- Start with three providers. Three providers unreachable, or a named member
  unavailable: report it and stop; don't substitute. Later rounds may run with
  fewer members (see Members who add little).
- Give each the request and relevant context. Review or feedback stays
  read-only.

## Keep the state in a file

Keep one file for this council and update it every round: each finding
(member, category, the fix meant to address it, status) and each member's
status (active, rested or dropped, with round and reason). Put it where the
user's instructions keep agent files, else in the session's scratch folder;
never in the repo. After compaction or a restart, continue from this file.

## While they run

- Don't wait idle: check each result against the code on arrival and decide
  fixes while the others run.
- No file edits while a delegate still reviews the same checkout.
- A delegate the user's instructions mark non-blocking: don't wait for it.
  Give it a fixed commit or its own worktree, so it never blocks edits. It
  is never rested or dropped and doesn't count toward "at least two active"; its late findings join the next round's
  findings list; its score is not recorded.
- Summarize useful findings, disagreements, and recommended next steps.

## Investigations and design choices

When the council is asked for a root cause, an investigation or a design
choice rather than a review of finished work:
- One read-only round: no fixes in between and no scores.
- Each member answers with evidence (files, lines, logs, commands).
- Check every claim against the code. Report the agreed findings, each
  disagreement with both sides' evidence, and the recommended next step.
- Run at most one more round, only if members contradict each other on
  something the evidence can settle: send each the others' claims and evidence.
- The sections below on scores, resting and rounds don't apply.

## Scores and rounds

Code review: each delegate scores out of 10 in every round. A full review
pass is one round; a fresh review after fixes starts a new round.

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

## Members who add little

After each round, sort every finding you checked against the code:
- **new**: true, and no other member found it;
- **repeat**: true, but another member already found it;
- **still present**: an earlier finding the member shows is not, or only
  partly, fixed. It counts as a true finding;
- **wrong**: false, made up, or irrelevant to the request;
- **unchecked**: you couldn't verify it. Never count it as wrong.

Starting with the results of round 2:
- **Rest a member** whose last round had no new and no still-present
  findings, only repeats or nothing. It sits out the following rounds.
- **Drop a member** whose last round had no true findings (new, repeat or
  still present) and mostly wrong ones. It stays out for the rest of this
  council, including the last look.
- **Keep a member that disagrees.** Disagreement backed by evidence is the
  panel working; judge only whether its findings are true and new.
- The Claude member (the one from Anthropic) is never rested or dropped, even
  when it adds nothing that round; the user wants Claude in every council.
- At least two members stay active. If that isn't possible, continue with
  Claude and the other member with the most new true findings so far (ties:
  the most still-present findings, then the higher latest score), and say so.
  If the user named members without one from Anthropic, keep the two with the
  most.
- **Last look:** when a round converges, give each rested member the diff
  from the commit it last reviewed to now and the findings list, and ask only for
  problems not on that list. If it finds a new true problem, fix it and run
  one more round with that member active again; that round counts toward the
  checkpoint. Each member gets one last look at most. Otherwise the council
  ends.
- In the score table, write `rested` or `dropped (round N: reason)` instead of
  a score.

## Keep later rounds cheap

- Starting with round 2, send each member the diff from the commit it last
  reviewed to now and the findings list (each finding with the fix meant to address
  it), not the whole context again.
- The diff and the findings list are where to start, not a limit. A member
  with access to the checkout reads any file it needs. A member without file
  access lists the files it needs; send them, then wait for its review.
- Ask three things: for each finding a fix was meant to address, "fixed,
  still present, or partly fixed", with evidence; then only problems not
  already on the list, or "nothing new"; and a score out of 10 for the work
  as it stands now.

## How many rounds

- A round converges when the active members find no new true problem and
  every earlier finding is fixed or accepted by you, with the reason in the
  state file. Then give rested
  members their last look (see Members who add little).
- Checkpoint after 3 rounds for a routine review (one area, a few files,
  tests can check the result), or after 6 for a large or open-ended one (a
  plan, design or spec; several areas or modules; a public API; a schema or
  data migration; security-sensitive code). A number named in the request
  replaces these. State it in the first message to members and in the report.
- The council is user-started when the user asked for it in a message in
  this session. A council that another skill or a standing instruction starts
  (for example, a lead's review before a merge request) is agent-started.
- At a checkpoint, without convergence:
  - User-started: show the remaining disagreements, with each member's
    position and evidence, and ask the user whether to continue. If yes,
    checkpoint again after the same number of rounds.
  - Agent-started: continue only if the last round found a new true problem;
    otherwise stop, and put the remaining disagreements in the report. Stop
    in any case at twice the checkpoint; then skip last looks and report.

## Iterate

Make the changes you agree with, request a fresh review, and repeat until a
round converges and the last looks are done, or a checkpoint says stop.
Fight scope creep across rounds; keep scope limited.
