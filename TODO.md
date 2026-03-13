---
title: "Plugin-based scaffold refactor for ralph-loop template"
created: 2026-03-09
updated: 2026-03-09
status: draft
target_repo: qte77/ralph-loop-cc-tdd-wt-vibe-kanban-template
tracking: template#7, plugin#15
depends_on: plan-claude-code-utils-plugin-embedded-dev-hooks-and-ralph-skill
phases: 11
---

**Target repo:** `qte77/ralph-loop-cc-tdd-wt-vibe-kanban-template`
**Tracking issues:** template#7, plugin#15
**Prerequisite:** plugin#15 must land first (embedded-dev hooks/settings)

---

## Implementation Order

**Sequence matters — Plan 1 is a prerequisite for Plan 2.**

### Plan 1: Plugin repo updates (claude-code-utils-plugin)

Small, self-contained. Execute in a single session. Straightforward file
creation following existing patterns. 4 CREATEs, 2 MODIFYs.

- Add hooks + settings to `embedded-dev` plugin (issue plugin#15)
- Add missing `generating-prd-md-from-userstory-md` skill to `ralph` plugin
- Update READMEs for both plugins

**Plan 1 MUST land before Plan 2 starts.** Skills and settings deleted in
Plan 2 must already exist in their target plugins.

See: `claude-code-utils-plugin/TODO.md` for the full plan.

### Plan 2: Template scaffold refactor (this repo)

Large, breaking refactor. Split into 3 PRs:

| PR | Phases | Why separate |
|----|--------|--------------|
| A  | 1-2    | Scaffold mechanism + Makefile split — testable in isolation, no deletions yet |
| B  | 3-6    | Delete skills/settings/vscode, update devcontainer — the breaking change, one atomic swap |
| C  | 7-11   | Stubs, docs, CI — polish after the core refactor lands |

**Neither plan targets `embed-e2e-ralph`.** Both target external repos
(`claude-code-utils-plugin` and this repo). These plans are reference docs
for work to be done here.

---

## Context

The template repo is currently hardcoded for Python. This plan refactors it into a
language-agnostic scaffold where language-specific concerns (skills, settings, Makefile
recipes, toolchain install) are provided by `claude-code-utils-plugin` plugins.

### Reference implementation

The `embed-e2e-ralph` repo (embedded C project) already uses this pattern:

- `workspace-setup` plugin deploys base `.claude/settings.json` via SessionStart hook
- `embedded-dev` plugin provides language-specific skills
- `.claude/settings.local.json` holds language-specific permissions
- Makefile has language-specific recipes (`misra`, `lint_c`, `test_hw`)
- Devcontainer uses `onCreateCommand` for heavy toolchain, `postCreateCommand` for
  lightweight tools

### Plugin settings layering (already working)

```
workspace-setup plugin  →  .claude/settings.json       (base: statusline, context7, deny cat/grep/find, allow make/git)
python-dev plugin       →  .claude/settings.local.json (allow: uv sync, uv run pytest, uv run ruff)
embedded-dev plugin     →  .claude/settings.local.json (allow: gcc, cppcheck, clang-tidy, sqlite3, doxygen)
```

Claude Code merges `settings.json` + `settings.local.json` at runtime.
Both language plugins use copy-if-not-exists, guarded by tool detection (`uv` or `gcc`).

---

## Execution order

Complete these phases sequentially. Each phase must be fully done before the next.

### Phase 0: Preparation

**0.1** Clone or fork the template repo to a working branch.

**0.2** Read and understand the current file layout. Key files:

```
.claude/settings.json          # Full settings (to be deleted)
.claude/skills/                # 16 skills (ALL to be removed — provided by plugins)
.devcontainer/project/devcontainer.json  # Python-specific
Makefile                       # Python-specific recipes mixed with core
pyproject.toml                 # Python-specific (move to scaffolds/python/)
uv.lock                        # Python-specific (move to scaffolds/python/)
mkdocs.yaml                    # Python-specific (move to scaffolds/python/)
.vscode/                       # Redundant with devcontainer customizations
AGENT_LEARNINGS.md             # Symlink to ralph/LEARNINGS.md (unnecessary indirection)
AGENT_REQUESTS.md              # Symlink to ralph/REQUESTS.md (unnecessary indirection)
```

**0.3** Verify plugin availability. Confirm these plugins exist and are installable:

```bash
claude plugin install workspace-setup@qte77-claude-code-utils
claude plugin install python-dev@qte77-claude-code-utils
claude plugin install embedded-dev@qte77-claude-code-utils
claude plugin install ralph@qte77-claude-code-utils
claude plugin install commit-helper@qte77-claude-code-utils
claude plugin install codebase-tools@qte77-claude-code-utils
claude plugin install docs-generator@qte77-claude-code-utils
```

---

### Phase 1: Add scaffold selection mechanism

**1.1** Add `.scaffold` to `.gitignore`:

```
# Scaffold selection (local dev choice)
.scaffold
```

**1.2** Add `setup_scaffold` recipe to `Makefile`. Place it in the `# MARK: setup`
section, after `setup_dev`:

```makefile
SUPPORTED_SCAFFOLDS := python embedded

setup_scaffold:  ## Select language scaffold. Usage: make setup_scaffold LANG=python|embedded
	@if [ -z "$${LANG:-}" ]; then \
		echo "Usage: make setup_scaffold LANG=python|embedded"; \
		echo "Supported: $(SUPPORTED_SCAFFOLDS)"; \
		exit 1; \
	fi
	@case "$${LANG}" in \
		python|embedded) ;; \
		*) echo "Unsupported scaffold: $${LANG}. Supported: $(SUPPORTED_SCAFFOLDS)"; exit 1 ;; \
	esac
	@if [ -f .scaffold ]; then \
		old=$$(cat .scaffold); \
		if [ "$$old" != "$${LANG}" ]; then \
			echo "Switching scaffold: $$old -> $${LANG}"; \
			echo "Cleaning previous settings overlay ..."; \
			rm -f .claude/settings.local.json; \
		fi; \
	fi
	@echo "$${LANG}" > .scaffold
	@echo "Scaffold set to: $${LANG}"
	@echo "Run 'make setup_dev' to install toolchain, or rebuild the devcontainer."
```

**1.3** Add `setup_toolchain` recipe that dispatches based on `.scaffold`:

```makefile
setup_toolchain:  ## Install language toolchain based on .scaffold selection
	@lang=$$(cat .scaffold 2>/dev/null || echo ""); \
	if [ -z "$$lang" ]; then \
		echo "No scaffold selected. Run: make setup_scaffold LANG=python|embedded"; \
		exit 0; \
	fi; \
	case "$$lang" in \
		python)   $(MAKE) -s setup_uv ;; \
		embedded) $(MAKE) -s setup_embedded ;; \
		*)        echo "Unknown scaffold: $$lang"; exit 1 ;; \
	esac
```

**1.4** Add `setup_embedded` recipe to Makefile (does not exist in template today).
Copy from `embed-e2e-ralph/Makefile` lines 47-53:

```makefile
setup_embedded:  ## Install C/embedded toolchain (gcc, clang, cppcheck, sqlite3)
	echo "Installing embedded C toolchain ..."
	sudo apt-get update -qq
	sudo apt-get install -y -qq gcc clang clang-tidy clang-format cppcheck sqlite3 doxygen
	echo "gcc: $$(gcc --version | head -1)"
	echo "cppcheck: $$(cppcheck --version)"
	echo "sqlite3: $$(sqlite3 --version)"
```

**1.5** Update `.PHONY` to include the new targets:
`setup_scaffold setup_toolchain setup_embedded`

**1.6** Update `setup_project` to prompt for scaffold language. The existing
`ralph/scripts/setup_project.sh` already runs an interactive setup. Add a `LANG`
prompt so users run one command instead of two:

```bash
# In setup_project.sh, add prompt:
read -rp "Language scaffold [python/embedded]: " SCAFFOLD
echo "$SCAFFOLD" > .scaffold
```

This way `make setup_project` handles both project customization and scaffold
selection in a single interactive flow.

---

### Phase 2: Extract language-specific Makefile recipes

**2.1** Create `Makefile.python` with all Python-specific recipes extracted from
the current `Makefile`. These are:

- `ruff` (format + lint)
- `complexity` (cognitive complexity)
- `duplication` (jscpd)
- `test_all`, `test_quick`, `test_coverage`, `test_e2e`
- `type_check` (pyright)
- `validate` (Python version: ruff → test_coverage → type_check)
- `validate_quick`, `quick_validate`
- `docs_serve`, `docs_build` (mkdocs)

Each recipe should be copied verbatim from the current Makefile. The `validate`
target in `Makefile.python` overrides the core one.

**2.2** Create `Makefile.embedded` with embedded C recipes. Copy from
`embed-e2e-ralph/Makefile`:

- `pcb_check` (lines 83-90)
- `db_migrate` (lines 92-95)
- `db_seed` (lines 97-104)
- `trace_check` (lines 106-108)
- `misra` (lines 110-125)
- `lint_c` (lines 127-135)
- `test_hw` (lines 137-145)
- `validate` (embedded version: lines 147-154)
- `docs_doxygen` (lines 160-168)

**2.3** Add conditional include to the core `Makefile`, near the top (after `.PHONY`
and `.DEFAULT_GOAL`):

```makefile
# Include language-specific recipes if scaffold is selected
-include Makefile.$(shell cat .scaffold 2>/dev/null)
```

**2.4** Remove the Python-specific recipes from the core `Makefile`. After this,
the core Makefile should only contain:

- Setup recipes: `setup_dev`, `setup_claude_code`, `setup_npm_tools`, `setup_lychee`,
  `setup_scaffold`, `setup_toolchain`, `setup_embedded`, `setup_project`
- Markdown lint: `lint_md`, `lint_links`, `run_markdownlint`
- Pandoc/writeup: `setup_pdf_converter`, `pandoc_run`, `writeup`, `writeup_generate`
- Ralph lifecycle: all `ralph_*` recipes
- Vibe kanban: all `vibe_*` recipes
- Help: `help`
- A fallback `validate` target in core that tells the user to select a scaffold:

```makefile
validate:  ## Run validation (requires scaffold selection)
	@if [ ! -f .scaffold ]; then \
		echo "No scaffold selected. Run: make setup_scaffold LANG=python|embedded"; \
		exit 1; \
	fi
	@echo "Error: validate should be provided by Makefile.$$(cat .scaffold)"
	@exit 1
```

**2.5** Update `.PHONY` in core Makefile to remove extracted Python targets. Add
`.PHONY` declarations inside each `Makefile.*` file for their own targets.

---

### Phase 3: Remove language-specific skills

**3.1** Delete these skill directories from `.claude/skills/`:

```
.claude/skills/implementing-python/        # provided by python-dev plugin
.claude/skills/testing-python/             # provided by python-dev plugin
.claude/skills/reviewing-code/             # provided by python-dev / embedded-dev plugin
.claude/skills/designing-backend/          # provided by backend-design plugin
.claude/skills/designing-mas-plugins/      # provided by mas-design plugin
.claude/skills/auditing-website-accessibility/  # provided by website-audit plugin
.claude/skills/auditing-website-usability/      # provided by website-audit plugin
.claude/skills/securing-mas/               # provided by mas-design plugin
.claude/skills/researching-website-design/ # provided by website-audit plugin
```

**3.2** Delete ALL remaining skills — they are provided by plugins too:

```
.claude/skills/committing-staged-with-message/  # provided by commit-helper plugin
.claude/skills/compacting-context/              # provided by codebase-tools plugin
.claude/skills/generating-interactive-userstory-md/  # provided by ralph plugin
.claude/skills/generating-prd-json-from-prd-md/      # provided by ralph plugin
.claude/skills/generating-prd-md-from-userstory-md/  # provided by ralph plugin (needs adding)
.claude/skills/generating-writeup/              # provided by docs-generator plugin
.claude/skills/researching-codebase/            # provided by codebase-tools plugin
```

After this step, `.claude/skills/` should be empty and can be deleted entirely.
Zero skills checked into the template — all come from plugins. Single source of truth.

**NOTE:** Verify each skill exists in its target plugin before deleting. If a skill
is missing from its plugin (e.g. `generating-prd-md-from-userstory-md` not yet in
`ralph` plugin), file an issue on `claude-code-utils-plugin` to add it before
deleting from the template. Do not delete a skill that has no plugin home yet.

**3.3** Delete `.claude/skills/` directory itself once empty.

---

### Phase 4: Delete checked-in settings.json

**4.1** Delete `.claude/settings.json` from the repo.

This file is now deployed by the `workspace-setup` plugin on first SessionStart.

**4.2** Delete `.claude/settings.local.json` if it exists in the repo.

This file is deployed by language plugins (`python-dev` or `embedded-dev`).

**4.3** Verify `.claude/.claude.json` is not affected (this is user preferences,
unrelated to plugin settings).

**4.4** Keep `.claude/rules/` as-is. These behavioral rules are project-specific
and should stay checked in. The `workspace-setup` plugin also deploys base rules
via copy-if-not-exists, so project rules take precedence.

**4.5** Keep `.claude/scripts/` as-is or delete if they are identical to what
`workspace-setup` deploys (e.g. `statusline.sh`). If the template has customizations,
keep them.

---

### Phase 5: Update devcontainer

**5.1** Edit `.devcontainer/project/devcontainer.json`:

Change the image from Python-specific to a generic base:

```json
"image": "mcr.microsoft.com/devcontainers/base:bookworm"
```

(If the current image is `mcr.microsoft.com/vscode/devcontainers/python:3.13`,
replace it.)

**5.2** Update lifecycle commands:

```json
"onCreateCommand": "make setup_toolchain",
"postCreateCommand": "make setup_claude_code && make setup_npm_tools && make setup_lychee"
```

**5.3** Update VS Code extensions to be a union of both scaffolds. Merge the Python
extensions (already present) with the embedded C extensions. Add:

```json
"llvm-vs-code-extensions.vscode-clangd",
"ms-vscode.cpptools",
"ms-vscode.cmake-tools",
"ms-vscode.makefile-tools"
```

Keep existing Python extensions (`ms-python.python`, `ms-python.vscode-pylance`,
`charliermarsh.ruff`, etc.). Unused extensions are harmless.

**5.4** Remove `UV_LINK_MODE` and `UV_CACHE_DIR` from `containerEnv` — these are
Python-specific. If needed, the `setup_uv` recipe can set them at runtime.
Keep `LOAD_DOTENV` and `DEBIAN_FRONTEND`.

**5.5** Leave `.devcontainer/template/devcontainer.json` unchanged (lightweight
container for editing the template itself).

---

### Phase 6: Clean up Python-specific root files and redundancies

**6.1** Move `pyproject.toml` from repo root to `scaffolds/python/pyproject.toml.template`.
The `setup_scaffold LANG=python` recipe copies it to the project root.

**6.2** Move `uv.lock` from repo root to `scaffolds/python/uv.lock`. Same copy
mechanism. (Or regenerate via `uv sync` during `setup_uv` — cleaner.)

**6.3** Move `mkdocs.yaml` from repo root to `scaffolds/python/mkdocs.yaml`.
MkDocs is Python-specific tooling; embedded projects use Doxygen instead.

**6.4** Delete `.vscode/` directory. The `.devcontainer/project/devcontainer.json`
already declares VS Code extensions and editor settings via the `customizations.vscode`
block. Having both is redundant and risks drift between the two configs.

**6.5** Delete `AGENT_LEARNINGS.md` and `AGENT_REQUESTS.md` symlinks from the repo
root. These point to `ralph/LEARNINGS.md` and `ralph/REQUESTS.md` respectively.
Agents and docs should reference `ralph/LEARNINGS.md` directly — the symlinks add
indirection with no value.

---

### Phase 7: Add scaffold file stubs

**7.1** Create `scaffolds/` directory with per-language stubs:

```
scaffolds/
├── python/
│   ├── src/
│   │   └── .gitkeep
│   ├── tests/
│   │   └── .gitkeep
│   └── pyproject.toml.template
└── embedded/
    ├── src/
    │   └── .gitkeep
    ├── test/
    │   └── .gitkeep
    ├── hw/
    │   └── .gitkeep
    ├── schema/
    │   └── requirements.sql
    └── Doxyfile.template
```

The `setup_scaffold` recipe (phase 1.2) should copy these stubs into the project
root when a scaffold is selected. Use copy-if-not-exists to avoid overwriting
user work.

**7.2** Copy `schema/requirements.sql` from `embed-e2e-ralph`:

```
/workspaces/embed-e2e-ralph/schema/requirements.sql
```

**7.3** Copy `Doxyfile` from `embed-e2e-ralph` as `Doxyfile.template`. The
`setup_scaffold LANG=embedded` recipe copies it to the project root.

**7.4** Update `setup_scaffold` recipe (from phase 1.2) to also copy stubs:

```makefile
setup_scaffold:  ## Select language scaffold. Usage: make setup_scaffold LANG=python|embedded
	@if [ -z "$${LANG:-}" ]; then \
		echo "Usage: make setup_scaffold LANG=python|embedded"; exit 1; fi
	@case "$${LANG}" in python|embedded) ;; \
		*) echo "Unsupported: $${LANG}"; exit 1 ;; esac
	@if [ -f .scaffold ]; then \
		old=$$(cat .scaffold); \
		if [ "$$old" != "$${LANG}" ]; then \
			echo "Switching scaffold: $$old -> $${LANG}"; \
			rm -f .claude/settings.local.json; fi; fi
	@echo "$${LANG}" > .scaffold
	@echo "Copying scaffold stubs ..."
	@if [ -d "scaffolds/$${LANG}" ]; then \
		cp -rn scaffolds/$${LANG}/. . 2>/dev/null || \
		rsync -a --ignore-existing scaffolds/$${LANG}/ .; fi
	@echo "Scaffold set to: $${LANG}"
	@echo "Next: rebuild devcontainer or run 'make setup_dev'"
```

---

### Phase 8: Update setup_dev

**8.1** Modify `setup_dev` to call `setup_toolchain` instead of hardcoding
Python setup:

```makefile
setup_dev:  ## Install dev tools + language toolchain
	echo "Setting up dev environment ..."
	$(MAKE) -s setup_claude_code
	$(MAKE) -s setup_npm_tools
	$(MAKE) -s setup_lychee
	$(MAKE) -s setup_toolchain
```

This way `setup_dev` works both inside devcontainer and standalone.

---

### Phase 9: Update AGENTS.md and CONTRIBUTING.md

**9.1** Update `AGENTS.md` to be language-agnostic. Remove Python-specific
references (`ruff`, `pytest`, `pyright`). Add scaffold-aware language:

- "Run `make validate` (behavior depends on selected scaffold)"
- "Language-specific skills are provided by plugins, not checked into the repo"

**9.2** Update `CONTRIBUTING.md` to document:

- Scaffold selection: `make setup_scaffold LANG=python|embedded`
- Available scaffolds and what each provides
- Plugin installation (automatic via devcontainer, manual via `claude plugin install`)

**9.3** Update `README.md` quickstart section:

```markdown
## Quick Start

1. Open in devcontainer (`.devcontainer/project/`)
2. Select a scaffold: `make setup_scaffold LANG=python`
3. Start developing: `make validate`
```

---

### Phase 10: Update CI/CD

**10.1** Edit `.github/workflows/validate.yml` to support both scaffolds.
Use a matrix strategy:

```yaml
strategy:
  matrix:
    scaffold: [python, embedded]
steps:
  - uses: actions/checkout@v4
  - run: echo "${{ matrix.scaffold }}" > .scaffold
  - run: make setup_toolchain
  - run: make setup_dev
  - run: make validate
```

**10.2** Alternatively, if CI should only validate the scaffold that the project
uses, read `.scaffold` from a default or environment variable:

```yaml
env:
  DEFAULT_SCAFFOLD: python
steps:
  - run: echo "${DEFAULT_SCAFFOLD}" > .scaffold
```

---

### Phase 11: Validation

Run these checks before merging:

**11.1** Python scaffold:

```bash
make setup_scaffold LANG=python
make setup_dev
make validate
# Verify: ruff, pytest, pyright all run
```

**11.2** Embedded scaffold:

```bash
rm -f .scaffold .claude/settings.local.json
make setup_scaffold LANG=embedded
make setup_dev
make validate
# Verify: trace_check, misra, test_hw all run (or skip gracefully with no source)
```

**11.3** Scaffold switch:

```bash
make setup_scaffold LANG=python
make setup_scaffold LANG=embedded
# Verify: .claude/settings.local.json was cleaned and re-created
```

**11.4** Clean state (no scaffold):

```bash
rm -f .scaffold
make validate
# Verify: prints "No scaffold selected" message, exits 1
```

**11.5** Plugin deployment:

```bash
rm -f .claude/settings.json .claude/settings.local.json
# Start new Claude Code session
# Verify: workspace-setup deploys settings.json
# Verify: python-dev or embedded-dev deploys settings.local.json
```

---

## File change summary

| Action | File | Notes |
|--------|------|-------|
| CREATE | `.scaffold` entry in `.gitignore` | Local dev choice |
| CREATE | `Makefile.python` | Extracted Python recipes |
| CREATE | `Makefile.embedded` | Extracted embedded C recipes |
| CREATE | `scaffolds/python/` | pyproject.toml, uv.lock, mkdocs.yaml, src/, tests/ |
| CREATE | `scaffolds/embedded/` | schema/, hw/, test/, src/, Doxyfile |
| MODIFY | `Makefile` | Add scaffold/toolchain recipes, remove Python recipes, add `-include` |
| MODIFY | `ralph/scripts/setup_project.sh` | Add scaffold LANG prompt to interactive setup |
| MODIFY | `.devcontainer/project/devcontainer.json` | Generic image, lifecycle dispatch, union extensions |
| MOVE | `pyproject.toml` → `scaffolds/python/` | Python-specific, not root-level |
| MOVE | `uv.lock` → `scaffolds/python/` | Python-specific (or regenerate via `uv sync`) |
| MOVE | `mkdocs.yaml` → `scaffolds/python/` | Python-specific docs tooling |
| DELETE | `.vscode/` | Redundant with devcontainer customizations |
| DELETE | `AGENT_LEARNINGS.md` | Symlink to ralph/LEARNINGS.md — unnecessary indirection |
| DELETE | `AGENT_REQUESTS.md` | Symlink to ralph/REQUESTS.md — unnecessary indirection |
| DELETE | `.claude/settings.json` | Deployed by workspace-setup plugin |
| DELETE | `.claude/settings.local.json` | Deployed by language plugins |
| DELETE | `.claude/skills/` (entire directory) | ALL skills now provided by plugins |
| MODIFY | `AGENTS.md` | Language-agnostic, reference ralph/ directly |
| MODIFY | `CONTRIBUTING.md` | Document scaffold workflow |
| MODIFY | `README.md` | Updated quickstart |
| MODIFY | `.github/workflows/validate.yml` | Matrix or scaffold-aware CI |

---

## Design notes

### settings.local.json single-target conflict

Both `python-dev` and `embedded-dev` deploy to `.claude/settings.local.json`.
The copy-if-not-exists pattern means whichever plugin's hook runs first in a session
where both tools are detected wins. This is acceptable because:

1. Only one scaffold is active at a time in practice
2. The template's `make setup_scaffold` cleans `settings.local.json` on switch
3. A future `settings.d/` directory pattern could support merging if Claude Code
   adds support

### Scope boundary

This plan covers ONLY the template repo changes. It does NOT cover:

- Plugin repo updates (see `claude-code-utils-plugin/TODO.md`)
- New plugins (no new plugins are created)
- Changes to `workspace-setup`, `python-dev`, `codebase-tools`, `commit-helper`,
  or `docs-generator` — all required skills already exist in these plugins
