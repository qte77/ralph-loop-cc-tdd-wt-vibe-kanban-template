---
name: researching-website-design
description: Website design research and competitive analysis. Use when exploring visual design patterns, typography, and layout conventions for a domain.
compatibility: Designed for Claude Code
metadata:
  allowed-tools: Read, Write, WebFetch, WebSearch
---

# Website Design Research

**Target**: $ARGUMENTS

Core question: "How would users naturally expect this information organized
if they had never seen a website?"

## Workflow

1. **Find websites** — Search "[industry] companies/platforms", target 6-8 sites
2. **Extract design elements** — Colors (hex), typography, layout hierarchy, CTAs
3. **Track sources** — URL, authority level (H/M/L), cited research, cross-refs
4. **Identify anomalies** — Who breaks conventions with better UX results?
5. **Synthesize findings** — Breakthroughs, patterns, contrarian insights, quick wins

## Output Format

### Source Index

```markdown
1. [Company] - [URL] - Authority: [H/M/L]
   Cites: [Studies/sources referenced]
   Cross-refs: [Shared sources with other sites]
```

### Design Breakthroughs (Max 3)

```markdown
BREAKTHROUGH #N (Impact: N/100)
Pattern: [What they do differently]
Principle: [Why it works]
Opportunity: [How to apply]
Sources: [Evidence]
```

### Visual and Content Patterns

```markdown
COLORS: Primary #HEX, Accent #HEX
TYPOGRAPHY: Headers [font], Body [font]
HEADLINES: [Pattern] + [User psychology]
CTAS: [Button text] + [Action driver]
```

### Contrarian Insights

```markdown
Everyone: [Common practice]
Reality: [What creates better UX]
Evidence: [Sources]
```

### Quick Wins

```markdown
ELIMINATE: [What to remove]
SIMPLIFY: [What to streamline]
ADOPT: [What to add]
```

## Rules

- Focus exclusively on visual design, layout, typography, content
- Extract exact values: hex codes, font names, button text
- Track cross-references to identify authoritative sources
- No time estimates
