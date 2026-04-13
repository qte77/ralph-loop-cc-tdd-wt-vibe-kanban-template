---
title: "Everything-Agnostic Ecosystem"
created: 2026-03-09
updated: 2026-03-13
status: in-progress
target_repos:
  - qte77/ralph-loop-cc-tdd-wt-vibe-kanban-template
  - qte77/claude-code-plugins
phases: 8
---

## Summary

Make everything agnostic: language, domain, toolchain, workflow, editor.
Template becomes a pure orchestration skeleton. Plugins bring all content.
Research keeps plugins current.

## Phases

| Phase | Repo | Scope | Status |
|-------|------|-------|--------|
| **1** | Template | Adapter system: `adapter.sh`, refactor Ralph lib scripts | done |
| **2** | Template | Scaffold mechanism: `.scaffold`, Makefile cleanup | done |
| **3** | Plugin | Python scaffold: `python-dev/scaffold/` + deploy hook | done |
| **4** | Template | Strip Python files, clean AGENTS.md + CONTRIBUTING.md | done |
| **5** | Plugin | Embedded scaffold: `embedded-dev/scaffold/` | done |
| **6** | Plugin | Skill protection: metadata, content-hash, CODEOWNERS, CI | in-progress |
| **7** | Plugin | GTM market-research plugin: skills + rules + hook + config | in-progress |
| **8** | Research | Improve research-compare.py, feedback loop | future |
| **9** | Template | Bug-fix sprint: 8 audit bugs + BATS TDD (see `docs/PRD.md`) | in-progress |
| **10** | Template | Self-evolving loop: progress injection, LEARNINGS check, distillation | in-progress |

## Adapter Interface

Ralph scripts call `adapter_*` functions defined in `.scaffolds/<name>.sh`:

- `adapter_test` / `adapter_lint` / `adapter_typecheck` / `adapter_complexity`
- `adapter_validate` / `adapter_coverage`
- `adapter_signatures` / `adapter_file_pattern`
- `adapter_env_setup` / `adapter_app_docs`

Scaffolds deployed by plugin SessionStart hooks (copy-if-not-exists).

## Verification

- `make setup_scaffold LANG=python` + Ralph scripts use adapter calls
- Without `.scaffold/` → fallback no-ops, `make validate` still works
- Fresh clone: zero language-specific files until scaffold selected
- Plugin install → SessionStart deploys adapter + settings + workflows
