---
name: leaving-pr-comments
description: Formats agent-written GitHub comments with an attribution note. Use whenever leaving comments on GitHub.
---

# Leaving PR Comments

Prefix every agent-authored comment left on the user's behalf with this GitHub
note callout:

```md
> [!NOTE]
> 🤖 **<model> responding on behalf of <user>**

Actual comment starts here.
```

- `<model>`: the verified public name of the model that wrote the comment; if
  the harness exposes none, the harness name. Don't guess. `<user>`: the
  user's name or GitHub login.
- Attribution inside the note, the reply outside it. The context line starts
  with the robot emoji. No horizontal rule, Setext underline, heading,
  signature footer, or second attribution.
- Applies to top-level PR comments, inline review comments, replies to bots or
  reviewers, and written explanations before resolving or dismissing feedback.
  Not to PR descriptions, commit messages, or text the user explicitly asked
  to post verbatim without attribution.

Before posting, check the entire comment, including quoted text and
attachments, for secrets and private details.

Write the comment directly:

- Lead with the conclusion.
- Cite the relevant code, behavior, check, or reproduction.
- Be concise: no filler, canned thanks, or status narration.
- Separate verified facts from judgment.

Preview the final Markdown before posting so quoting and blank lines render as
shown. After posting, verify GitHub returned the comment or review URL.
Resolve a review thread only after its response posted successfully.
