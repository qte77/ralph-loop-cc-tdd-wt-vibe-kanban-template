# Ralph Loop - Iteration Prompt

You are executing a single story from the Ralph autonomous development loop.

## Critical Rules (Apply FIRST)

- **Core Principles**: Auto-applied via rules - KISS, DRY, YAGNI, user-centric
- **MANDATORY**: Read and follow `AGENTS.md` compliance requirements
- **One story only**: Complete the current story, don't start others
- **Atomic changes**: Keep changes focused and minimal
- **Quality first**: All changes must pass `make validate`
- **No scope creep**: Implement exactly what the story requires

## Your Task

Follow TDD workflow below. Tests MUST be written FIRST.

## Workflow (TDD - MANDATORY)

**RED → GREEN → BLUE cycle:**

### RED: Write tests FIRST

- Read story from prd.json, write tests for acceptance criteria
  - Create test file in `tests/` (e.g., `tests/test_messenger.py`)
  - Write tests that verify each acceptance criterion
  - Run tests - they MUST fail (implementation doesn't exist yet)
  - **RUN VALIDATION**: `make validate` - fix any errors before committing
  - **COMMIT TESTS FIRST**:
    `git add tests/ && git commit -m "test(STORY-XXX): add tests for feature [RED]"`

### GREEN: Implement to make tests pass

- Study patterns in `src/`, implement MINIMAL code to pass tests
  - Create/modify implementation file (e.g., `src/agentbeats/messenger.py`)
  - Write simplest code that makes tests pass
  - Run tests - they MUST pass now
  - **RUN VALIDATION**: `make validate` - fix any errors before committing
  - **COMMIT IMPLEMENTATION**:
    `git add src/ && git commit -m "feat(STORY-XXX): implement feature [GREEN]"`

### BLUE: Refactor (OPTIONAL)

- **Only if needed**: Refactor code/tests while keeping tests passing
  - Violations of DRY (duplicated logic)
  - Violations of KISS (unnecessary complexity)
  - Inconsistency with existing patterns
  - **RUN VALIDATION**: `make validate` before committing
  - **COMMIT REFACTORINGS** - Be specific in description and scope:
    - Tests only: `refactor(STORY-XXX/tests): rename fixtures for clarity [BLUE]`
    - Implementation only: `refactor(STORY-XXX/impl): extract validation helper [BLUE]`
    - Both: `refactor(STORY-XXX/both): consolidate duplicate logic [BLUE]`
    - Style fixes: `style(STORY-XXX/impl): fix linting errors [BLUE]`

**BLUE is optional** - Skip if code is already clean and follows existing patterns.

**CRITICAL**: Tests MUST be committed BEFORE implementation. This ensures
verifiable TDD compliance and provides audit trail for agent evaluation.

## Before Writing Code (DRY CHECK - MANDATORY)

**Automatically check for existing code to reuse:**

1. Run `ls src/*/config/` → Import existing config if present
2. Run `ls src/*/models/` → Import existing models if present
3. Run `grep -r "class.*BaseModel" src/` → Find existing Pydantic models

**Import existing code, don't duplicate:**

```python
# ✅ CORRECT - Reuse existing
from myproject.models import ExistingModel
from myproject.config import Config

# ❌ WRONG - Duplicate definition
class ExistingModel(BaseModel):  # Already exists elsewhere!
    pass
```

## Available Skills

You have access to these skills:

- `designing-backend` - For architecture decisions
- `implementing-python` - For Python code implementation
- `reviewing-code` - For self-review before completion

Use skills appropriately based on task requirements.

## Quality Gates

Run `make validate` before marking complete. See `CONTRIBUTING.md` for all
validation commands.

## After Story Completion

**MANDATORY**: Review and compound before finishing. Each learning makes future
stories easier.

### COMPOUND Phase

Document learnings to make future work easier.

**Step 1: Reflect and identify learning**

Answer these questions:
1. **What worked?** - Pattern/approach that succeeded
2. **What failed initially?** - Mistake + how you fixed it
3. **What should future iterations remember?** - Key learning

**Step 2: Append to LEARNINGS.md**

Add to appropriate section in `ralph/LEARNINGS.md`:

- **Validation Fixes**: What fixed validation errors
  - Format: `- [STORY-XXX] Brief description of fix`
- **Code Patterns**: Discovered codebase conventions
  - Format: `- Pattern description (discovered in STORY-XXX)`
- **Common Mistakes**: Errors to avoid
  - Format: `- Mistake description (from STORY-XXX)`
- **Testing Strategies**: Effective testing approaches
  - Format: `- Strategy description (from STORY-XXX)`

**Guidelines:**
- Keep entries concise (1 line each)
- Focus on actionable insights that benefit future iterations
- Avoid duplicating existing entries

**Note**: LEARNINGS.md is periodically reviewed using `/review-learnings` command to prune duplicates and obsolete entries.

**Cross-repo context**: When `## Compound Learnings` appears below, it contains
story-relevant patterns from related projects. Apply them only if directly
applicable — they are informational, not prescriptive.

## Current Story Details

(Will be appended by ralph.sh for each iteration)
