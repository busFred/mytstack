---
name: takeover
description: Takes over a PR, branch, or agent thread and finishes its goal, keeping contributor credit. Use when the user asks to take over one, or requests a takeover.
---

# Takeover

Finish the original goal while preserving the original contributors' credit.
Don't defend an implementation just because another agent built it.

- **Source.** Read the source PR, branch, or thread, including review findings
  and the user's later corrections. Resolve the handoff to the actual code and
  current head; account for uncommitted work. The handoff is context, not
  proof.
- **Branch.** For a replacement PR, import the original commits onto a new
  branch and add your fixes separately. Honor an explicitly requested
  in-place or stacked continuation instead. Don't overwrite unrelated work or
  change the original PR without authorization.
- **Credit.** Preserve Git authorship and existing co-author trailers. Credit
  the original contributors in the PR description and link the original PR if
  any. If the work will be squashed, keep human author/co-author credit in the
  merge commit, with verified identities, not guessed emails. Model
  attribution doesn't replace contributor credit.
- **Update.** Use `modernize` to update the continuation against its
  intended base and current architecture. Rework what finishing the same goal needs, not unrelated
  features. Simplify without dropping intended behavior or surfaces. Recheck
  the source PR; it may have improved meanwhile.
- **Verify** the original failure and realistic workflows independently,
  following repo guidance and permissions. Green mocked tests don't prove the
  user experience. State what remains unverified.
- **Finish.** If the requested finish includes a PR, file or update it with
  `file-pr`, then `babysit-pr` rather than stopping at creation. Use
  `leaving-pr-comments` for replies. Merge or close the original PR only when
  authorized.

Report what you inherited, what you changed, how you verified it, how credit
was preserved, and any remaining decision.
