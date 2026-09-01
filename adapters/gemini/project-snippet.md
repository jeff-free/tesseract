<!-- tesseract-start -->
# Tesseract Knowledge Base

This project is linked to Tesseract domain: **{{DOMAIN_NAME}}**

Knowledge path: `{{DOMAIN_DIR}}`
Local symlink: `tesseract/`

## Structure

- `tesseract/index.md`: index page — lists all knowledge files (`## Files`) and Changelog
- `tesseract/<topic>.md`: knowledge files — one file per topic

## Rules

1. Before starting work: read `tesseract/index.md` to find relevant knowledge files; read related `<topic>.md`
2. Proactively update (without user asking) when: design decision made, problem solved, user preference observed, important insight found
3. How to update:
   - Find the matching `<topic>.md` and update it; if none exists, create one
   - Use `#tag` to label topics, `[[filename]]` to link related knowledge files
   - Never write knowledge content into `index.md` (it is index only)
   - When adding a new file: add a line to `## Files` in `index.md`
   - Append one line to `## Changelog` in `index.md`: `- YYYY-MM-DD: description (AI)`
4. Never store code in the knowledge base — only knowledge, insights, decisions, preferences
<!-- tesseract-end -->
