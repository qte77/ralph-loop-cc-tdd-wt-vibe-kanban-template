---
name: committing-staged-with-message
description: Generate commit message for staged changes, pause for approval, then commit. Stage files first with `git add`, then run this skill.
compatibility: Designed for Claude Code
metadata:
  model: haiku
  disable-model-invocation: true
  argument-hint: (no arguments needed)
  allowed-tools: Bash, Read, Glob, Grep
---

# Commit Staged Changes with Generated Message

## Size Guard

If staged changes exceed **10 files OR 500 lines**: skip full diff analysis,
use `git diff --staged --stat` only for the commit body.

## Step 1: Analyze Changes

Using Bash tool:

- `git diff --staged --stat` - Summary of changed files and line counts
- `git diff --staged` - Full diff (skip if size guard triggers)
- `git log --oneline -5` - Check recent commit style

Using Read/Glob tools as needed to understand file purposes.

## Step 2: Generate Commit Message

See `.gitmessage` for expected syntax.

Format:

```text
<type>(<scope>): <subject>

<body>

<diff stats>
```

Rules:

- Concise and laser-focused subject line
- Body explains what changed (organized by file or logical group)
- Include relevant symbols added/removed
- **Diff stats as final body line** (from `--stat` output)
- No repetition of subject line in body

## Step 3: Pause for Approval

**Please review the commit message.**

- **Approve**: "yes", "y", "commit", "go ahead"
- **Edit**: Provide your preferred message
- **Cancel**: "no", "cancel", "stop"

## Step 4: Commit

Once approved:

- `git commit -m "[message]"` - Commit with approved message
- `git status` - Verify success
