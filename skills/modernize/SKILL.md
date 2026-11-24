---
name: modernize
description: >-
  Reassesses and rebases an old PR, recommending MODERNIZE, REWORK, or CLOSE.
  Use only when the user asks to rebase a PR or says "modernize".
---

# Modernize

Modernize the idea, not just the branch: a clean rebase doesn't prove the PR
still belongs in the product.

## Guardrails

- Before starting, pull latest origin for your branch, the main branch, and
  any other branch related to the work.
- Existing worktree changes are user-owned. Use a disposable worktree when the
  active one is dirty or in use for other work.
- Modernizing authorizes rebasing and updating the PR branch, not merging,
  closing, changing the base branch, or expanding scope.
- Never force push unqualified: use `--force-with-lease` against the head SHA
  observed before the rebase.
- No PR comment unless the user asked; use `leaving-pr-comments` for every
  comment posted on the user's behalf.

## Establish the PR's intent

Resolve the PR; record its URL, state, base, head repository and branch,
current head SHA, author, checks, and review state. Read the title, body,
linked issues, commits, review threads, and complete diff. State the smallest
coherent goal the PR was trying to accomplish before judging its
implementation.

Fetch the latest remote base and PR head, using the PR's actual base branch
(usually `main`), rather than assuming the local branch is current. Record the merge base to compare the
original PR and later base-branch changes separately.

## Check what changed around it

Inspect commits and diffs added to the base since the PR diverged. Search
merged and open PRs when titles, code paths, or behavior suggest a
replacement or competing implementation. Look beyond overlapping lines:

- Has the same user-facing problem already been solved?
- Did APIs, types, schemas, dependencies, or architectural boundaries change?
- Do both sides now claim ownership of the same behavior or invariant?
- Was the code being changed deleted, moved, or intentionally simplified?
- Would landing the PR restore an old behavior or create two ways to do the
  same thing?
- Is the original benefit still large enough to justify the maintenance cost?

Don't call a PR current just because Git reports no conflicts.

## Choose a disposition before pushing

- **MODERNIZE**: goal still useful, implementation still the right shape.
  Rebase, resolve conflicts, test, update the branch.
- **REWORK**: goal still useful, but a mechanical rebase would keep the wrong
  implementation. Explain the smallest credible rewrite; stop before pushing
  unless the user also asked for that rework.
- **CLOSE**: superseded, obsolete, directionally wrong, or no longer worth its
  cost. Cite concrete evidence and stop. Don't rebase an obsolete branch, and
  don't close it without explicit permission.

Be willing to recommend `CLOSE`. Age alone isn't evidence; sunk effort isn't a
reason to keep a PR alive.

## Rebase without losing intent

For `MODERNIZE`:

1. Create a safe local branch or disposable worktree at the recorded PR head.
2. Rebase its commits onto the freshly fetched base branch.
3. Resolve each conflict by the PR's current intent and the base's newer
   invariants. If a conflict reveals a product or architecture disagreement,
   stop and reconsider the disposition instead of guessing.
4. Compare pre- and post-rebase series with `git range-diff` and inspect the
   final diff: no intentional behavior lost, no already-landed behavior
   reintroduced.
5. Run the repo's focused checks for the touched area. Tell real failures from
   pre-existing or infrastructure ones.
6. Push with `--force-with-lease` tied to the previously observed remote head.
   If the lease fails, fetch and reassess; don't overwrite new work.

Don't merge the PR.

## Report

Lead with `MODERNIZE`, `REWORK`, or `CLOSE` and the reason, then:

- meaningful changes on the base branch;
- conceptual conflicts, or confirmation none were found;
- the rebase and push result, if performed;
- checks run and their results;
- the remaining decision or work, with a link to the PR.

Separate observed facts from judgment. Say what couldn't be verified rather
than manufacturing confidence.
