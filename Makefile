# This Makefile automates build, test, and project-setup tasks.
# Language-specific recipes live in Makefile.<lang> and are auto-included
# based on the contents of .scaffold (written by `make setup_scaffold`).
# Run `make help` to see all available recipes.

.SILENT:
.ONESHELL:
.PHONY: setup_scaffold setup_toolchain setup_dev setup_claude_code setup_npm_tools setup_lychee validate run_markdownlint lint_md lint_links ralph_validate_json ralph_create_userstory_md ralph_create_prd_md ralph_create_prd_json ralph_init_loop ralph_run ralph_worktree ralph_run_worktree ralph_init_and_run ralph_reorganize_prd ralph_status ralph_stop ralph_clean ralph_archive ralph_watch ralph_get_log vibe_start vibe_stop_all vibe_status vibe_cleanup help
.DEFAULT_GOAL := help

# Auto-include language-specific Makefile when .scaffold exists
-include Makefile.$(shell cat .scaffold 2>/dev/null)


# MARK: scaffold


setup_scaffold:  ## Initialize scaffold for a language. Usage: make setup_scaffold LANG=python|embedded
	if [ -z "$(LANG)" ]; then
		echo "ERROR: LANG is required. Usage: make setup_scaffold LANG=python|embedded"
		exit 1
	fi
	case "$(LANG)" in
		python|embedded) ;;
		*)
			echo "ERROR: Unsupported LANG '$(LANG)'. Supported: python, embedded"
			exit 1
		;;
	esac
	echo "$(LANG)" > .scaffold
	echo "Scaffold set to: $(LANG)"
	echo "Run 'make setup_toolchain' to install language toolchain"

setup_toolchain:  ## Install toolchain for the active scaffold (reads .scaffold)
	if [ ! -f .scaffold ]; then
		echo "ERROR: .scaffold file not found. Run 'make setup_scaffold LANG=<lang>' first"
		exit 1
	fi
	LANG=$$(cat .scaffold)
	echo "Setting up toolchain for language: $$LANG"
	case "$$LANG" in
		python)
			pip install uv -q
			uv sync --all-groups
			$(MAKE) -s setup_npm_tools
			$(MAKE) -s setup_lychee
			echo "Python toolchain ready"
		;;
		embedded)
			if ! command -v cmake > /dev/null 2>&1; then
				echo "ERROR: cmake not found — install cmake and a C compiler first"
				exit 1
			fi
			echo "Embedded toolchain ready (cmake: $$(cmake --version | head -1))"
		;;
		*)
			echo "ERROR: Unknown language '$$LANG' in .scaffold"
			exit 1
		;;
	esac


# MARK: setup


setup_dev:  ## Install dev tools + language toolchain (reads .scaffold)
	echo "Setting up dev environment ..."
	$(MAKE) -s setup_claude_code
	$(MAKE) -s setup_npm_tools
	$(MAKE) -s setup_lychee
	$(MAKE) -s setup_toolchain

setup_claude_code:  ## Setup claude code CLI, node.js and npm have to be present
	echo "Setting up Claude Code CLI ..."
	npm install -gs @anthropic-ai/claude-code
	echo "Claude Code CLI version: $$(claude --version)"

setup_npm_tools:  ## Setup npm-based dev tools (markdownlint, jscpd)
	echo "Setting up npm tools ..."
	npm install -gs markdownlint-cli jscpd
	echo "markdownlint: $$(markdownlint --version), jscpd: $$(jscpd --version)"

setup_lychee:  ## Install lychee link checker (Rust binary, requires sudo)
	curl -sL https://github.com/lycheeverse/lychee/releases/latest/download/lychee-x86_64-unknown-linux-gnu.tar.gz | sudo tar xz -C /usr/local/bin lychee
	echo "lychee version: $$(lychee --version)"

validate:  ## Run validation (delegates to scaffold adapter, no-op without scaffold)
	if [ -f .scaffold ] && type adapter_validate >/dev/null 2>&1; then \
		adapter_validate; \
	elif [ -f .scaffold ]; then \
		echo "No adapter_validate found — source ralph/scripts/lib/adapter.sh first"; \
	else \
		echo "No scaffold set — skipping validation (run 'make setup_scaffold LANG=<lang>' first)"; \
	fi


# MARK: run markdownlint


run_markdownlint:  ## Lint markdown files. Usage from root dir: make run_markdownlint INPUT_FILES="docs/**/*.md"
	if [ -z "$(INPUT_FILES)" ]; then
		echo "Error: No input files specified. Use INPUT_FILES=\"docs/**/*.md\""
		exit 1
	fi
	markdownlint $(INPUT_FILES) --fix


# MARK: lint


lint_md:  ## Lint markdown files - Usage: make lint_md FILES="docs/**/*.md"
	markdownlint $${FILES:-"*.md"} --fix

lint_links:  ## Check for broken links with lychee. Usage: make lint_links [INPUT_FILES="docs/**/*.md"]
	if command -v lychee > /dev/null 2>&1; then \
		lychee $(or $(INPUT_FILES),.); \
	else \
		echo "lychee not installed — skipping link check (run 'make setup_lychee' to install)"; \
	fi


# MARK: ralph


ralph_validate_json:  ## Internal: Validate prd.json syntax
	bash ralph/scripts/lib/validate_json.sh

ralph_create_userstory_md:  ## [Optional] Create UserStory.md interactively. No params.
	echo "Creating UserStory.md through interactive Q&A ..."
	claude -p '/generating-interactive-userstory-md'

ralph_create_prd_md:  ## [Optional] Generate PRD.md from UserStory.md. No params.
	echo "Generating PRD.md from UserStory.md ..."
	claude -p '/generating-prd-md-from-userstory-md'

ralph_create_prd_json:  ## [Optional] Generate prd.json from PRD.md (DRY_RUN=1 for parse-only)
	$(if $(DRY_RUN),python ralph/scripts/generate_prd_json.py --dry-run,echo "Generating prd.json from PRD.md ..." && claude -p '/generating-prd-json-from-prd-md')

ralph_init_loop:  ## Initialize Ralph loop environment. No params.
	echo "Initializing Ralph loop environment ..."
	claude -p '/generating-prd-json-from-prd-md'
	bash ralph/scripts/init.sh
	$(MAKE) -s ralph_validate_json

ralph_run:  ## Run Ralph loop - Usage: make ralph_run [N_WT=<N>] [ITERATIONS=<N>] [TIMEOUT=<seconds>] [MODEL=sonnet|opus|haiku] [TEAMS=true] [DRY_RUN=true] [INSTRUCTION="..."] [DESLOPIFY=true] [DEBUG=1] [KEEP_WORKTREES=true] [RALPH_JUDGE_ENABLED=true] [RALPH_SECURITY_REVIEW=true] [RALPH_MERGE_INTERACTIVE=true]
	echo "Starting Ralph loop (N_WT=$${N_WT:-}, iterations=$${ITERATIONS:-}) ..."
	$(MAKE) -s ralph_validate_json
	$(if $(TIMEOUT),timeout $(TIMEOUT)) \
	DEBUG=$${DEBUG:-} \
	RALPH_DRY_RUN=$${DRY_RUN:-} \
	RALPH_MODEL=$${MODEL:-} \
	RALPH_INSTRUCTION="$${INSTRUCTION:-}" \
	RALPH_DESLOPIFY=$${DESLOPIFY:-} \
	$(if $(filter true,$(TEAMS)),CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1) \
	RALPH_PARALLEL_KEEP_WORKTREES=$${KEEP_WORKTREES:-} \
	RALPH_JUDGE_ENABLED=$${RALPH_JUDGE_ENABLED:-} \
	RALPH_JUDGE_MODEL=$${RALPH_JUDGE_MODEL:-} \
	RALPH_JUDGE_MAX_WT=$${RALPH_JUDGE_MAX_WT:-} \
	RALPH_SECURITY_REVIEW=$${RALPH_SECURITY_REVIEW:-} \
	RALPH_MERGE_INTERACTIVE=$${RALPH_MERGE_INTERACTIVE:-} \
	env -u VIRTUAL_ENV bash ralph/scripts/parallel_ralph.sh "$${N_WT}" "$${ITERATIONS}" \
	|| { EXIT_CODE=$$?; [ $$EXIT_CODE -eq 124 ] && echo "Ralph loop timed out after $(TIMEOUT)s"; exit $$EXIT_CODE; }

ralph_worktree:  ## Create a git worktree for Ralph. Usage: make ralph_worktree BRANCH=ralph/sprint-name
	$(if $(BRANCH),,$(error BRANCH is required. Usage: make ralph_worktree BRANCH=ralph/sprint-name))
	env -u VIRTUAL_ENV bash ralph/scripts/ralph-in-worktree.sh "$${BRANCH}"

ralph_run_worktree:  ## Create worktree + run Ralph in it. Usage: make ralph_run_worktree BRANCH=required [ITERATIONS=<N>] [TIMEOUT=<seconds>] [MODEL=sonnet|opus|haiku] [TEAMS=true] [DRY_RUN=true] [INSTRUCTION="..."] [DESLOPIFY=true]
	$(if $(BRANCH),,$(error BRANCH is required. Usage: make ralph_run_worktree BRANCH=ralph/sprint-name))
	env -u VIRTUAL_ENV bash ralph/scripts/ralph-in-worktree.sh "$${BRANCH}" && \
	cd "../$$(basename $(BRANCH))" && \
	$(if $(TIMEOUT),timeout $(TIMEOUT)) \
	env -u VIRTUAL_ENV \
	RALPH_MODEL=$${MODEL:-} \
	RALPH_INSTRUCTION="$${INSTRUCTION:-}" \
	RALPH_DRY_RUN=$${DRY_RUN:-} \
	RALPH_DESLOPIFY=$${DESLOPIFY:-} \
	$(if $(filter true,$(TEAMS)),CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1) \
	bash ralph/scripts/ralph.sh "$${ITERATIONS:-}" \
	|| { EXIT_CODE=$$?; [ $$EXIT_CODE -eq 124 ] && echo "Ralph worktree timed out after $(TIMEOUT)s"; exit $$EXIT_CODE; }

ralph_init_and_run:  ## Initialize and run Ralph loop. Usage: make ralph_init_and_run [N_WT=<N>] [ITERATIONS=<N>] [TIMEOUT=<seconds>] [MODEL=sonnet|opus|haiku] [TEAMS=true] [DRY_RUN=true] [INSTRUCTION="..."] [DESLOPIFY=true] [DEBUG=1] [KEEP_WORKTREES=true] [RALPH_JUDGE_ENABLED=true] [RALPH_SECURITY_REVIEW=true] [RALPH_MERGE_INTERACTIVE=true]
	$(MAKE) -s ralph_init_loop
	$(MAKE) -s ralph_run N_WT=$${N_WT:-} ITERATIONS=$${ITERATIONS:-} TIMEOUT=$${TIMEOUT:-} MODEL=$${MODEL:-} TEAMS=$${TEAMS:-} DRY_RUN=$${DRY_RUN:-} INSTRUCTION="$${INSTRUCTION:-}" DESLOPIFY=$${DESLOPIFY:-} DEBUG=$${DEBUG:-} KEEP_WORKTREES=$${KEEP_WORKTREES:-} RALPH_JUDGE_ENABLED=$${RALPH_JUDGE_ENABLED:-} RALPH_SECURITY_REVIEW=$${RALPH_SECURITY_REVIEW:-} RALPH_MERGE_INTERACTIVE=$${RALPH_MERGE_INTERACTIVE:-}


ralph_reorganize_prd:  ## Archive current PRD and activate new one. Usage: make ralph_reorganize_prd NEW_PRD=docs/PRD-v2.md [VERSION=2]
	bash ralph/scripts/reorganize_prd.sh $${VERSION:+-v $${VERSION}} "$${NEW_PRD}"

ralph_status:  ## Show Ralph loop progress
	bash ralph/scripts/parallel_ralph.sh status

ralph_stop:  ## Stop Ralph loops and kill processes (keep worktrees and data)
	bash ralph/scripts/stop.sh

ralph_clean:  ## Clean Ralph state (worktrees + local) - Requires double confirmation
	bash ralph/scripts/clean.sh

ralph_archive:  ## Archive current run state. Usage: make ralph_archive [ARCHIVE_LOGS=1]
	bash ralph/scripts/archive.sh $(if $(filter 1,$(ARCHIVE_LOGS)),-l)

ralph_watch:  ## Live-watch Ralph loop output
	bash ralph/scripts/parallel_ralph.sh watch

ralph_get_log:  ## Show output of specific worktree - Usage: make ralph_get_log WT=2
	bash ralph/scripts/parallel_ralph.sh log $${WT:-1}


# MARK: vibe-kanban


vibe_start:  ## Start Vibe Kanban (default from config.sh, override: make vibe_start PORT=8080)
	bash ralph/scripts/vibe.sh start $${PORT:-}

vibe_stop_all:  ## Stop all Vibe Kanban instances
	bash ralph/scripts/vibe.sh stop_all

vibe_status:  ## Check Vibe Kanban status (shows all instances)
	bash ralph/scripts/vibe.sh status

vibe_cleanup:  ## Remove all tasks from Vibe Kanban
	bash ralph/scripts/vibe.sh cleanup


# MARK: help


help:  ## Displays this message with available recipes
	echo "Usage: make [recipe]"
	echo ""
	awk '/^# MARK:/ { \
		printf "\n\033[1;33m%s\033[0m\n", substr($$0, index($$0, ":")+2) \
	} \
	/^[a-zA-Z0-9_-]+:.*?##/ { \
		helpMessage = match($$0, /## (.*)/) ; \
		if (helpMessage) { \
			recipe = $$1 ; \
			sub(/:/, "", recipe) ; \
			printf "  \033[36m%-24s\033[0m %s\n", recipe, substr($$0, RSTART + 3, RLENGTH) \
		} \
	}' $(MAKEFILE_LIST)
