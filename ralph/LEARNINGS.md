# Agent Learnings

Accumulated knowledge from previous Ralph runs. Read this before starting each story, append relevant learnings after story completion.

## Validation Fixes

<!-- Append fixes that resolved validation errors -->
<!-- Format: "- [STORY-XXX] Brief description of fix" -->

## Code Patterns

<!-- Append discovered codebase conventions -->
<!-- Format: "- Pattern description (discovered in STORY-XXX)" -->
- Safe flag expansion pattern: `local -a flags_array; read -ra flags_array <<< "$flag_string"; command "${flags_array[@]}"` avoids eval injection (from STORY-002)
- Sentinel file pattern for exit codes: Worker subshell writes `echo $? > "$path/.sentinel-file"` and parent reads it back; fallback to default value (137) if missing (from STORY-003)
- Function name collisions across sourced scripts silently resolve to whichever was sourced last — use distinct names per script when semantics differ (from STORY-004)
- Use `get_story_base_commit "$story_id"` to convert story IDs to git commit hashes before passing to git diff operations (from STORY-005)
- Safe JSON construction pattern: Use `jq -n --arg key value --argjson bool true` with object merging `{...} + if $field != null then {field: $field} else {} end` for optional fields; never concatenate strings for JSON (from STORY-006)
- To test functions from scripts that call `main` at the bottom, use `awk '/^func_name\(\)/,/^}$/' script.sh > /tmp/func.sh && source /tmp/func.sh` — extracts only the function body without running the script (from STORY-007)

## Common Mistakes

- `claude -p` spawned from within a CC session (Bash tool or `!` prompt) inherits the read-only sandbox — `.git` is read-only, `git commit` fails silently. The agent falls back to `gitStatus` context instead of running the actual command. Always run `ralph.sh` from an independent terminal (Codespace terminal tab), never from within CC. (discovered during STORY-001 dogfooding, validated 2026-03-25)
- Never use `eval` to expand command-line flags, even if current values look safe. Indirect injection through env vars becomes possible. Always use safe array expansion. (from STORY-002)
- Don't hardcode exit codes for disowned processes — use sentinel files to capture actual exit codes. `disown` prevents `wait` from capturing the exit code, so subshells must write to a sentinel file. (from STORY-003)
- Passing story IDs (e.g., "STORY-005") instead of git commit hashes to `git diff` functions causes silent failures — git treats invalid refs as empty diffs, so quality checks pass vacuously. Always convert story IDs to commit hashes with `get_story_base_commit` before passing to scoped check functions. (from STORY-005)
- Using sed to escape JSON strings (e.g., `sed 's/"/\\"/g'`) is insufficient — it misses backslashes, newlines, and other special characters, enabling JSON injection. Always use `jq --arg` which properly escapes all JSON special characters. (from STORY-006)

## Testing Strategies

<!-- Append effective testing approaches -->
<!-- Format: "- Strategy description (from STORY-XXX)" -->
- Test exit code capture by creating sentinel files in isolated test directories and verifying their contents (from STORY-003)
- Test JSON payload construction by validating with `jq .` after construction, including special characters (quotes, newlines, backslashes) to catch injection vulnerabilities (from STORY-006)
- Count jq subprocess invocations via PATH-priority stub that increments a counter file; reset counter after sourcing to avoid counting setup overhead (from STORY-007)
