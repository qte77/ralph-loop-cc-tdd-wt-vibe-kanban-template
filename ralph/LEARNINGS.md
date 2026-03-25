# Agent Learnings

Accumulated knowledge from previous Ralph runs. Read this before starting each story, append relevant learnings after story completion.

## Validation Fixes

<!-- Append fixes that resolved validation errors -->
<!-- Format: "- [STORY-XXX] Brief description of fix" -->

## Code Patterns

<!-- Append discovered codebase conventions -->
<!-- Format: "- Pattern description (discovered in STORY-XXX)" -->

## Common Mistakes

- `claude -p` spawned from within a CC session (Bash tool or `!` prompt) inherits the read-only sandbox — `.git` is read-only, `git commit` fails silently. The agent falls back to `gitStatus` context instead of running the actual command. Always run `ralph.sh` from an independent terminal (Codespace terminal tab), never from within CC. (discovered during STORY-001 dogfooding, validated 2026-03-25)

## Testing Strategies

<!-- Append effective testing approaches -->
<!-- Format: "- Strategy description (from STORY-XXX)" -->
