---
name: generating-writeup
description: Academic/technical writeups with Pandoc-compatible markdown. Use for documentation, reports, or technical explanations.
---

# Technical Writeup Generation

Creates **structured technical documentation** in Pandoc-compatible markdown.
Suitable for academic papers, technical reports, and documentation.

## Workflow

1. **Define scope** - Audience, purpose, length constraints
2. **Outline structure** - Logical section progression
3. **Write content** - Clear, precise technical language
4. **Add formatting** - Pandoc-compatible markdown
5. **Review and refine** - Clarity, accuracy, completeness

## Document Structure

```markdown
---
title: "Document Title"
author: "Author Name"
date: YYYY-MM-DD
abstract: |
  Brief summary of document contents and key findings.
---

# Introduction

Context and motivation...

# Background

Prior work and foundational concepts...

# Methodology / Approach

Technical details of the approach...

# Results / Implementation

Findings or implementation details...

# Discussion

Analysis and implications...

# Conclusion

Summary and future work...

# References
```

## Formatting Standards

**Code Blocks:**

```python
# Use language hints for syntax highlighting
def example():
    return "formatted code"
```

**Tables:**

| Header 1 | Header 2 |
|----------|----------|
| Data     | Data     |

**Citations:**

Use `[@citation-key]` for Pandoc citations.

**Math:**

Inline: `$E = mc^2$`
Block: `$$\int_0^\infty f(x) dx$$`

## Output Formats

**Academic:** Full structure with abstract, citations, formal language
**Technical:** Focused on implementation, code examples, diagrams
**Report:** Executive summary, findings, recommendations

## Quality Checks

- [ ] Structure follows logical progression
- [ ] Technical terms defined on first use
- [ ] Code examples are runnable
- [ ] Citations are complete
- [ ] Pandoc-compatible markdown
