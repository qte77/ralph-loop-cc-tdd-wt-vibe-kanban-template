---
name: committing-staged-with-message
description: Generate commit message for staged changes, pause for approval, then commit. Stage files first with `git add`, then run this skill.
compatibility: Designed for Claude Code
metadata:
  model: haiku
  argument-hint: (no arguments needed)
  allowed-tools: Bash, Read, Glob, Grep
---

# Commit Staged Changes with Generated Message

## Step 1: Analyze Changes

Using Bash tool:

- `git status --porcelain` - List all changed files
- `git diff --staged` and `git diff` - Review changes
- `git log --oneline -10` - Check recent commit style

Using Read/Glob tools as needed to understand file purposes.

## Step 2: Generate Commit Message

See `.gitmessage` for expected syntax.

Format:

```text
<type>(<scope>): <subject>

<body>
```

## Step 3: Pause for Approval

**Please review the commit message.**

- **Approve**: "yes", "y", "commit", "go ahead"
- **Edit**: Provide your preferred message
- **Cancel**: "no", "cancel", "stop"

## Step 4: Commit

Once approved:

- `git add .` - Stage all changes
- `git commit -m "[message]"` - Commit with approved message
- `git status` - Verify success
