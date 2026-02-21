# Writeup Template

## Frontmatter (00_frontmatter.md)

```yaml
---
title: "Document Title"
bibliography: references.bib
reference-section-title: References
nocite: ""
---
```

## BibTeX (references.bib)

```bibtex
@article{key2024,
  author  = {Last, First},
  title   = {Article Title},
  journal = {Journal Name},
  year    = {2024},
  volume  = {1},
  pages   = {1--10},
  doi     = {10.xxxx/xxxxx}
}

@inproceedings{key2024conf,
  author    = {Last, First},
  title     = {Paper Title},
  booktitle = {Conference Name},
  year      = {2024},
  pages     = {1--10}
}

@book{key2024book,
  author    = {Last, First},
  title     = {Book Title},
  publisher = {Publisher},
  year      = {2024}
}

@online{key2024web,
  author  = {Last, First},
  title   = {Page Title},
  url     = {https://example.com},
  urldate = {2024-01-01}
}
```

## Citation Syntax

| Syntax | Renders As | Use Case |
|--------|-----------|----------|
| `[@key]` | [1] | Standard citation |
| `[@key1; @key2]` | [1, 2] | Multiple citations |
| `[-@key]` | suppress author | Author already mentioned |
| `@key says...` | Author (year) says... | Author-in-text (APA) |

## Document Structure

### Simple

```text
docs/write-up/<topic>/
├── 00_frontmatter.md
├── 01_introduction.md
├── 02_methods.md
├── 03_results.md
├── 04_conclusion.md
└── references.bib
```

### Complex

```text
docs/write-up/<topic>/
├── 00_frontmatter.md
├── 01_introduction.md
├── 02_background.md
├── 03_methodology.md
├── 04_implementation.md
├── 05_results.md
├── 06_discussion.md
├── 07_conclusion.md
├── 08_references.md
├── 09_appendix.md
├── diagrams/
└── references.bib
```
