# Context Management (ACE-FCA)

**MANDATORY for efficient token utilization.**

## Context Quality Equation

Quality output = Correct context + Complete context + Minimal noise

## Degradation Hierarchy (worst to best)

1. **Incorrect information** - cascading errors
2. **Missing information** - leads to guessing
3. **Excessive noise** - dilutes signal, wastes capacity

## Utilization Target: 40-60% capacity

- **Warning threshold**: Above 70% triggers compaction
- **Critical threshold**: Above 85% requires immediate compaction

## Context Pollution Sources (compact immediately)

- File searches (glob/grep results)
- Code flow traces
- Edit applications
- Test/build logs
- Large JSON blobs from tools

## Workflow Phases

Research → Planning → Implementation. Compact after each phase transition.

## Compaction Triggers

Use `compacting-context` skill when:

- Verbose tool output (logs, JSON, search results)
- After completing a phase or milestone
- Before starting new complex task

## Subagent Usage

Use `researching-codebase` skill to isolate discovery artifacts.

## Output Format Guidelines

**Prefer concise formats:**

- Single-line summaries for status updates
- Bullet points over paragraphs
- Tables for structured comparisons
- Code snippets with context, not full files
- `file:line` references instead of quoting code

**Avoid:**

- Multi-paragraph explanations for simple changes
- Repeating user instructions back verbatim
- Including unchanged code in edit descriptions
- Verbose error messages when line references suffice
