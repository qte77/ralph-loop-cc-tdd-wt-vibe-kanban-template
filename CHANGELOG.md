<!-- markdownlint-disable MD024 no-duplicate-heading -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Types of changes**: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`

## [Unreleased]

### Added

- Claude Code configuration (`.claude.json`)
- Context management rules (`.claude/rules/context-management.md`)
- Extended skill set: testing-python, compacting-context, researching-codebase,
  generating-writeup, auditing-accessibility, securing-mas
- Quality thresholds and role boundaries in AGENTS.md
- Enhanced CONTRIBUTING.md with testing requirements and code standards
- SECURITY.md with vulnerability reporting process
- GitHub Actions workflows (pytest, ruff, codeql)
- MkDocs documentation setup (`mkdocs.yaml`)
- Devcontainer Ollama variant
- MCP configuration (`.mcp.json`)
- Ralph Loop: Claude-as-Judge for intelligent parallel worktree selection
- Ralph Loop: Vibe Kanban real-time UI integration for live progress tracking
- Ralph Loop: Auto-resume for paused worktrees
- Ralph Loop: Process tree display in `ralph_watch`
- Ralph Loop: Comprehensive scoring metrics and DEBUG mode
- Ralph Loop: Timestamp to status command
- Ralph Loop: PYTHONPATH isolation for worktree modules
- Ralph Loop: RED → GREEN → BLUE TDD phase ordering enforcement
- Validation: Cognitive complexity checks via complexipy integration

### Changed

- Ralph Loop: CLI returns immediately in normal mode (background execution)
- Ralph Loop: Append to progress.txt instead of resetting
- Ralph Loop: Separated stop and cleanup operations for better control
- Ralph Loop: Consolidated Vibe Kanban management into single script
- Ralph Loop: Renamed prompt.md to story.prompt.md for clarity
- Ralph Loop: Improved cleanup UX and watch process filtering
- Makefile: Standardized Ralph command naming convention (`ralph_*`)

### Fixed

- Ralph Loop: Preserve worktrees on graceful shutdown (SIGINT/SIGTERM/SIGKILL)
- Ralph Loop: Preserve worktrees on interrupt (Ctrl+C)
- Ralph Loop: Require 100% story completion before merge
- Ralph Loop: Error 255 auto-recovery and cleanup logic
- Ralph Loop: SCRIPT_DIR collision in library files
- Ralph Loop: Removed git push from worktree branches
- Ralph Loop: Mark already-complete stories as 'done' in Vibe Kanban
- Ralph Loop: Worktree detection and pstree output formatting
- Ralph Loop: Vibe task status categorization and dynamic config
- Ralph Loop: Export RALPH_RUN_ID to worktree subprocess for env file sourcing
