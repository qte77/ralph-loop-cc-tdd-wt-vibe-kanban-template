---
name: researching-codebase
description: Evidence-based codebase investigation. Use when exploring unfamiliar code, understanding architecture, or gathering context for implementation.
---

# Codebase Research

Conducts **evidence-based investigation** of codebases to gather accurate
context. Never assume - always verify through code examination.

## Workflow

1. **Define research question** - What specific information is needed?
2. **Identify search strategy** - Files, patterns, dependencies
3. **Gather evidence** - Read actual code, not assumptions
4. **Document findings** - File:line references, direct quotes
5. **Synthesize conclusions** - Answer research question with evidence

## Research Strategies

**Architecture Understanding:**

```bash
# Project structure
tree -L 2 src/
# Entry points
grep -r "def main" src/
# Dependencies
cat pyproject.toml | grep dependencies
```

**Code Flow Tracing:**

```bash
# Find function definitions
grep -rn "def function_name" src/
# Find usages
grep -rn "function_name(" src/
# Find imports
grep -rn "from.*import.*function_name" src/
```

**Pattern Discovery:**

```bash
# Find similar implementations
grep -rn "class.*Base" src/
# Find configuration patterns
grep -rn "@dataclass" src/
```

## Evidence Standards

**Always include:**

- File path and line number: `src/module.py:42`
- Direct code quotes when relevant
- Dependency relationships

**Never:**

- Assume code behavior without reading it
- Reference libraries not in pyproject.toml
- Guess at implementation details

## Output Format

```markdown
## Research: [Question]

### Findings

1. **[Topic]** - `file.py:line`
   - Evidence: [direct quote or summary]
   - Implication: [what this means]

### Conclusions

[Answer to research question with evidence references]
```

## Quality Checks

- [ ] All claims backed by file:line references
- [ ] No assumptions about unread code
- [ ] Dependencies verified in pyproject.toml
- [ ] Findings answer the research question
