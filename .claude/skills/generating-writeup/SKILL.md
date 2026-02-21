---
name: generating-writeup
description: Academic/technical writeups with Pandoc-compatible markdown. Use for documentation, reports, or technical explanations.
compatibility: Designed for Claude Code
metadata:
  allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Technical Writeup Generation

Creates **structured technical documentation** in Pandoc-compatible markdown.
Suitable for academic papers, technical reports, and documentation.

## Workflow

1. **Define scope** - Audience, purpose, length constraints
2. **Outline structure** - Logical section progression
3. **Write content** - Clear, precise technical language
4. **Add formatting** - Pandoc-compatible markdown
5. **Add citations** - BibTeX references, see `template.md` for syntax
6. **Review and refine** - Clarity, accuracy, completeness

## Document Structure

```yaml
---
title: "Document Title"
author: "Author Name"
date: YYYY-MM-DD
bibliography: references.bib
reference-section-title: References
abstract: |
  Brief summary of document contents and key findings.
---
```

See `template.md` in this skill directory for full template with
frontmatter, BibTeX examples, and directory structure.

## Citation Styles

| Style | Format | Example |
|-------|--------|---------|
| IEEE | numeric | [1] |
| APA | author-date | (Author, 2024) |
| Chicago | author-date | (Author 2024) |
| Vancouver | numeric | (1) |

Alternatives available from the [Zotero Style Repository](https://www.zotero.org/styles).

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

## Pandoc Integration

```bash
# Generate PDF from markdown sections
pandoc 0*.md -o output.pdf --citeproc --number-sections
```

**CRITICAL**: NEVER add manual section numbers to headings.
Use `--number-sections` flag in pandoc. Manual "2. Section" creates
duplicate numbering in PDFs.

## Output Formats

**Academic:** Full structure with abstract, citations, formal language
**Technical:** Focused on implementation, code examples, diagrams
**Report:** Executive summary, findings, recommendations

## Quality Checks

- [ ] Structure follows logical progression
- [ ] Technical terms defined on first use
- [ ] Code examples are runnable
- [ ] No manual section numbering in headings
- [ ] Citation keys match bibliography entries
- [ ] markdownlint passes
- [ ] Pandoc-compatible markdown
