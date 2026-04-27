---
title: Agent Guidelines
version: 2.0
applies-to: all-agents
purpose: Define Agent Neutrality Requirements and task execution protocol
---

# Agent Guidelines

## Agent Guidelines

For general contribution guidelines (core principles, testing, validation),
see `CONTRIBUTING.md`.

### Agent-Specific Requirements

When working on this project, agents must:

1. **Use Ralph Loop skills** - Leverage specialized skills from
   `.claude/skills/` for phase planning, implementation, and review tasks

### Quality Thresholds

All agent outputs must meet minimum quality scores:

| Dimension | Minimum Score | Description |
|-----------|---------------|-------------|
| Context | 8/10 | Accurate understanding of requirements |
| Clarity | 7/10 | Clear, unambiguous output |
| Alignment | 8/10 | Matches stated task scope |

### Agent Role Boundaries

**Architects** - Design only, no implementation:

- Create specifications and diagrams
- Define interfaces and contracts
- Document architectural decisions

**Developers** - Implement per specification:

- Follow architect designs exactly
- Write code matching stated requirements
- Run validation before completion

**Reviewers** - QA only, no modifications:

- Validate against requirements
- Identify issues with evidence
- Provide actionable feedback

### Mandatory Prohibitions

Agents MUST NOT:

- [ ] **Assume missing context** - Ask or research, never guess
- [ ] **Hallucinate libraries** - Only use verified dependencies in the project manifest
- [ ] **Delete code without instruction** - Preserve existing functionality
- [ ] **Over-engineer solutions** - Match complexity to task scope
- [ ] **Skip validation** - Always run `make validate` before completion

### Compliance Requirements

1. **Use make recipes exclusively** - No direct tool commands
2. **Run `make validate` before completion** - All checks must pass
3. **Update ralph/LEARNINGS.md** - Document discoveries and patterns
4. **Follow existing patterns** - Study `src/` before implementing
5. **Reference file:line** - Always cite evidence for claims
