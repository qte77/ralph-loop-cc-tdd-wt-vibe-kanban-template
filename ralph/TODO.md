---
title: Ralph TODO
purpose: Consolidated backlog for Ralph loop — code quality, enhancements, and deferred items.
created: 2026-03-08
updated: 2026-03-08
---

## Code Quality

- [ ] **SC2181: Replace `$?` check with direct exit code** in
  `parallel_ralph.sh:888`. Use `if ! judge_winner=$(judge_worktrees ...)`
  instead of `local judge_winner=$(...); if [ $? -ne 0 ]`.
  See [ShellCheck SC2181](https://www.shellcheck.net/wiki/SC2181).

- [ ] **Reduce complexity in `generate_prd_json.py:646-775`** (complexity=16).
  Extract helper functions from the long method. Consider: Extract Method,
  Decompose Conditional patterns.
