# Feishu Formatting Rules

## Goal

Preserve semantic structure first, then preserve presentation where feasible.

## Title

- Prefer the first H1 as the remote document title.
- Remove that H1 from the uploaded body when the CLI sends the title separately.

## Headings

- Preserve standard Markdown headings.
- Do not skip heading levels without a reason.

## Lists

- Preserve flat ordered and unordered lists.
- Rewrite fragile nested indentation into clearer flat sections when needed.

## Code blocks

- Preserve fenced blocks with triple backticks.
- Preserve language tags when present.
- Do not convert code blocks into inline code.

## Tables

- Preserve standard Markdown pipe tables.
- Normalize malformed but obvious header rows.
- Convert unrecoverable tables into bullet lists rather than shipping broken table syntax.

## Mermaid and flowcharts

- Raw Mermaid should not be dropped.
- Convert Mermaid to a readable fallback by adding a short explanation and preserving the diagram content in a code block.
- If the user explicitly asks for rendered diagrams in Feishu, explain that an additional render-to-image step may be required.

## Blockquotes

- Preserve standard `>` blockquotes.
- Convert custom admonition syntaxes into blockquotes or headings plus paragraphs.

## HTML

- Remove or simplify unsupported embedded HTML where possible.
- Prefer plain Markdown equivalents.

## File naming

- Remote title comes from article title.
- Local temporary filenames may remain mechanical.
- Do not use the local filename as the Feishu title unless the user explicitly asks for that behavior.
