---
name: council
description: Runs a scored review panel of models from different providers (a full council of three, or a pair), or a read-only investigation of a root cause or a design choice. Use when the user says 'council', or when the user's instructions or another skill call for one; never start one otherwise.
---

# Council

Before a code review, address open PR comments, fix known issues and run the checks, so members see the current code (skip this for code being discarded).

## Size: pair or full

A council costs every member's usage on every round, so use the smallest that fits:
- **Pair (default):** one Claude model and one model from another provider (e.g. GPT), one round. For tools, scripts, tests, docs, routine code, and every investigation.
- **Full (three providers):** only when the user asks for a full council, names three or more members, or the caller's rules require it (e.g. code whose mistakes lose data, break security or change the product's core behaviour; a design, plan or public API).

Members: the ones the user's instructions name; else each provider's latest flagship (e.g. Claude Opus, GPT Sol, Gemini Pro), high effort in round 1, medium in re-check rounds. In T3 Code, resolve models with `orchestrator_capabilities` and start one `delegate_task` per member, in parallel; elsewhere, the harness's subagent tools. An unavailable member: report it and don't substitute. Every brief says read-only.

## While it runs

- Keep one state file (in the user's agent-files folder, else the session scratch folder; never the repo): each finding with member, severity, the fix meant for it and its status. After compaction, continue from it.
- Check each result against the code as it arrives; sort findings into **new**, **repeat** (another member found it), **still present**, **wrong** or **unchecked** (couldn't verify; never counted as wrong).
- No file edits while a member still reviews the same checkout. A member the user marks non-blocking gets a fixed commit or its own worktree, and you don't wait for it.

## Investigations and design choices

One read-only round, no fixes and no scores. Start with a blind pair (neither sees the other's answer) at matching tiers; add a third member only when the two disagree on something the evidence can't settle. Each answers with evidence (files, lines, logs, commands). Check every claim against the code; report agreed findings, each disagreement with both sides' evidence, and the next step.

## Review rounds

- **Round 1:** every member reviews and scores out of 10.
- **Re-check rounds:** only the members whose findings were blockers (high severity: wrong results, data loss, security, a broken build or test) re-check, with the diff since they last looked and the findings list. Ask: each of their findings fixed, still present or partly fixed (with evidence); only new problems not on the list; a score.
- **Another round only for a new or still-present blocker.** Medium and low findings: fix them if cheap and say so, or list them as follow-ups; they never start a round.
- **Stop at 3 rounds.** Without convergence: report the open blockers with each side's evidence. If the user started the council, ask whether to continue; otherwise stop. A number the user names replaces 3.
- Fight scope creep: findings outside the request become follow-ups.

## Report

Scores per member per round; write `no score` when there is none, and `not re-checked` for a member that sat out. If the work ends in a PR, edit (don't comment) its description with this section before the model and harness line:

```markdown
## Council review

Rounds: 2

| Delegate | Round 1 | Round 2 |
| --- | --- | --- |
| Claude Opus | 7/10 | 9/10 |
| GPT Sol | 8/10 | not re-checked |
```

No PR: the same table in the final reply.
