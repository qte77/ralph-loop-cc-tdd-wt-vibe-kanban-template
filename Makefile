# This Makefile automates the build, test, and clean processes for the project.
# It provides a convenient way to run common tasks using the 'make' command.
# It is designed to work with the 'uv' tool for managing Python environments and dependencies.
# Note: UV_LINK_MODE could be configured in .devcontainer/project/devcontainer.json
# Run `make help` to see all available recipes.

.SILENT:
.ONESHELL:
.PHONY: setup_dev setup_claude_code setup_markdownlint setup_npm_tools setup_sandbox setup_agent_docs setup_project run_markdownlint ruff complexity duplication lint_md lint_hardcoded_paths lint_links test_all test_quick test_coverage test_e2e type_check validate validate_quick quick_validate docs_serve docs_build ralph_validate_json ralph_create_userstory_md ralph_create_prd_md ralph_init_loop ralph_run ralph_reorganize_prd ralph_status ralph_clean ralph_archive ralph_abort ralph_watch ralph_get_log vibe_start vibe_stop_all vibe_status vibe_cleanup help
.DEFAULT_GOAL := help


# MARK: setup


setup_dev:  ## Install uv and deps, Download and start Ollama 
	echo "Setting up dev environment ..."
	pip install uv -q
	uv sync --all-groups
	echo "npm version: $$(npm --version)"
	$(MAKE) -s setup_claude_code
	$(MAKE) -s setup_markdownlint

setup_claude_code:  ## Setup claude code CLI, node.js and npm have to be present
	echo "Setting up Claude Code CLI ..."
	npm install -gs @anthropic-ai/claude-code
	echo "Claude Code CLI version: $$(claude --version)"

setup_markdownlint:  ## Setup markdownlint CLI, node.js and npm have to be present
	echo "Setting up markdownlint CLI ..."
	npm install -gs markdownlint-cli
	echo "markdownlint version: $$(markdownlint --version)"

setup_sandbox:  ## Setup isolation tools (jscpd for copy-paste detection)
	echo "Setting up sandbox tools ..."
	npm install -gs jscpd
	echo "jscpd version: $$(jscpd --version)"

setup_npm_tools:  ## Install all npm CLI tools (markdownlint, jscpd, lychee)
	echo "Setting up npm tools ..."
	npm install -gs markdownlint-cli jscpd lychee
	echo "markdownlint: $$(markdownlint --version), jscpd: $$(jscpd --version)"
	echo "lychee version: $$(lychee --version)"

setup_agent_docs:  ## Create root-level symlinks for AGENT_LEARNINGS.md and AGENT_REQUESTS.md
	[ -e AGENT_LEARNINGS.md ] || ln -s ralph/docs/LEARNINGS.md AGENT_LEARNINGS.md
	[ -e AGENT_REQUESTS.md ] || ln -s ralph/docs/REQUESTS.md AGENT_REQUESTS.md

setup_project:  ## Customize template with your project details. Run with help: bash ralph/scripts/setup_project.sh help
	bash ralph/scripts/setup_project.sh || { echo ""; echo "ERROR: Project setup failed. Please check the error messages above."; exit 1; }


# MARK: run markdownlint


run_markdownlint:  ## Lint markdown files. Usage from root dir: make run_markdownlint INPUT_FILES="docs/**/*.md"
	if [ -z "$(INPUT_FILES)" ]; then
		echo "Error: No input files specified. Use INPUT_FILES=\"docs/**/*.md\""
		exit 1
	fi
	markdownlint $(INPUT_FILES) --fix


# MARK: Sanity


ruff:  ## Lint: Format and check with ruff
	uv run ruff format --exclude tests
	uv run ruff check --fix --exclude tests

complexity:  ## Check cognitive complexity with complexipy
	uv run complexipy

duplication:  ## Check for code duplication with jscpd
	jscpd src/ --reporters console --format python

lint_md:  ## Lint markdown files - Usage: make lint_md FILES="docs/**/*.md"
	markdownlint $${FILES:-"*.md"} --fix

lint_hardcoded_paths:  ## GHA safety: check for /workspaces/ in test files
	echo "Checking for hardcoded /workspaces/ paths in tests..."
	if grep -rn --include='*.py' '/workspaces/' tests/ 2>/dev/null; then
		echo "ERROR: Found hardcoded /workspaces/ paths in tests (breaks GHA)"
		exit 1
	fi
	echo "No hardcoded paths found"

lint_links:  ## Check for broken links in markdown files
	echo "Checking for broken links..."
	command -v lychee >/dev/null 2>&1 || { echo "lychee not found. Run: make setup_npm_tools"; exit 1; }
	lychee $(or $(INPUT_FILES),.)

test_all:  ## Run all tests (excludes E2E tests by default)
	uv run pytest

test_quick:  ## Quick test - rerun only failed tests (use during fix iterations)
	uv run pytest --lf -x

test_coverage:  ## Run tests with coverage threshold (configured in pyproject.toml)
	echo "Running tests with coverage gate (fail_under=70% in pyproject.toml)..."
	uv run pytest --cov

test_e2e:  ## Run E2E tests only (Ralph parallel loop tests)
	echo "Running E2E tests..."
	bash ralph/scripts/tests/test_parallel_ralph.sh
	uv run pytest -m e2e -v

type_check:  ## Check for static typing errors
	uv run pyright

validate:  ## Complete pre-commit validation sequence
	set -e
	echo "Running complete validation sequence..."
	$(MAKE) -s ruff
	$(MAKE) -s type_check
	$(MAKE) -s complexity
	$(MAKE) -s test_coverage
	echo "Validation completed successfully"

validate_quick:  ## Quick validation for fix iterations (no coverage check)
	set -e
	echo "Running quick validation (no coverage check)..."
	$(MAKE) -s ruff
	$(MAKE) -s type_check
	$(MAKE) -s complexity
	$(MAKE) -s test_quick
	echo "Quick validation completed"

quick_validate:  ## Fast development cycle validation
	echo "Running quick validation ..."
	$(MAKE) -s ruff
	-$(MAKE) -s type_check
	-$(MAKE) -s complexity
	-$(MAKE) -s lint_hardcoded_paths
	echo "Quick validation completed (check output for any failures)"


# MARK: docs


docs_serve:  ## Serve MkDocs documentation locally
	uv run mkdocs serve

docs_build:  ## Build MkDocs documentation
	uv run mkdocs build


# MARK: ralph

ralph_validate_json:  ## Internal: Validate prd.json syntax
	bash ralph/scripts/lib/validate_json.sh

ralph_create_userstory_md:  ## [Optional] Create UserStory.md interactively. No params.
	echo "Creating UserStory.md through interactive Q&A ..."
	claude -p '/generating-interactive-userstory-md'

ralph_create_prd_md:  ## [Optional] Generate PRD.md from UserStory.md. No params.
	echo "Generating PRD.md from UserStory.md ..."
	claude -p '/generating-prd-json-from-prd-md'

ralph_init_loop:  ## Initialize Ralph loop environment. No params.
	echo "Initializing Ralph loop environment ..."
	claude -p '/generating-prd-json-from-prd-md'
	bash ralph/scripts/init.sh
	$(MAKE) -s ralph_validate_json

ralph_run:  ## Run Ralph loop - Usage: make ralph_run [N_WT=<N>] [ITERATIONS=<N>] [DEBUG=1] [RALPH_JUDGE_ENABLED=true] [RALPH_SECURITY_REVIEW=true] [RALPH_MERGE_INTERACTIVE=true]
	echo "Starting Ralph loop (N_WT=$${N_WT:-}, iterations=$${ITERATIONS:-}) ..."
	$(MAKE) -s ralph_validate_json
	DEBUG=$${DEBUG:-} \
	RALPH_JUDGE_ENABLED=$${RALPH_JUDGE_ENABLED:-} \
	RALPH_JUDGE_MODEL=$${RALPH_JUDGE_MODEL:-} \
	RALPH_JUDGE_MAX_WT=$${RALPH_JUDGE_MAX_WT:-} \
	RALPH_SECURITY_REVIEW=$${RALPH_SECURITY_REVIEW:-} \
	RALPH_MERGE_INTERACTIVE=$${RALPH_MERGE_INTERACTIVE:-} \
	bash ralph/scripts/parallel_ralph.sh "$${N_WT}" "$${ITERATIONS}"

ralph_init_and_run:  ## Initialize and run Ralph loop in one command. Usage: make ralph_init_and_run [N_WT=<N>] [ITERATIONS=<N>] [DEBUG=1] [RALPH_JUDGE_ENABLED=true] [RALPH_SECURITY_REVIEW=true] [RALPH_MERGE_INTERACTIVE=true]
	$(MAKE) -s ralph_init_loop
	$(MAKE) -s ralph_run N_WT=$${N_WT:-} ITERATIONS=$${ITERATIONS:-} DEBUG=$${DEBUG:-} RALPH_JUDGE_ENABLED=$${RALPH_JUDGE_ENABLED:-} RALPH_SECURITY_REVIEW=$${RALPH_SECURITY_REVIEW:-} RALPH_MERGE_INTERACTIVE=$${RALPH_MERGE_INTERACTIVE:-}


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
