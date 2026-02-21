---
name: generating-interactive-userstory-md
description: Interactive Q&A to build UserStory.md from user input. Replaces legacy build-userstory command.
compatibility: Designed for Claude Code
metadata:
  disable-model-invocation: true
  allowed-tools: AskUserQuestion, Read, Write, WebFetch, WebSearch
---

# Generate Interactive UserStory.md

## Workflow

1. **Check for existing UserStory.md** — If `docs/UserStory.md` exists,
   ask whether to rebuild (backs up existing file first)
2. **Ask structured questions** via AskUserQuestion:
   - Project name
   - Problem statement
   - Target users
   - Value proposition
   - User stories (as a user, I want... so that...)
   - Success criteria
   - Constraints
   - Out of scope
3. **Generate UserStory.md** from template at
   `ralph/docs/templates/userstory.md.template`
4. **Write** to `docs/UserStory.md`
5. **Suggest next step**: `make ralph_create_prd_md`

## Usage

```bash
make ralph_create_userstory_md
```

## Template Location

`ralph/docs/templates/userstory.md.template`
