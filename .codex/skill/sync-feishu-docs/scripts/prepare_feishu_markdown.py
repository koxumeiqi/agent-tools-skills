from __future__ import annotations

import argparse
import re
from pathlib import Path


def extract_title(text: str, fallback: str) -> str:
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("# "):
            title = stripped[2:].strip()
            if title:
                return title
    return fallback


def strip_duplicate_h1(text: str) -> str:
    lines = text.splitlines()
    for idx, line in enumerate(lines):
        if line.strip().startswith("# "):
            remaining = lines[idx + 1 :]
            while remaining and not remaining[0].strip():
                remaining = remaining[1:]
            result = "\n".join(remaining).strip()
            return result + ("\n" if result else "")
    return text if text.endswith("\n") else text + "\n"


def keep_h1(text: str) -> str:
    return text if text.endswith("\n") else text + "\n"


def normalize_code_fences(text: str) -> str:
    return text.replace("``` ", "```")


def is_table_separator(line: str) -> bool:
    stripped = line.strip()
    if not stripped or "|" not in stripped:
        return False
    cells = [cell.strip() for cell in stripped.strip("|").split("|")]
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells)


def normalize_tables(text: str) -> str:
    lines = text.splitlines()
    output: list[str] = []
    i = 0

    while i < len(lines):
        line = lines[i]
        if "|" in line:
            table: list[str] = []
            while i < len(lines) and "|" in lines[i].strip():
                table.append(lines[i])
                i += 1

            if len(table) >= 2 and is_table_separator(table[1]):
                output.extend(table)
                continue

            cells = [c.strip() for c in table[0].strip().strip("|").split("|")]
            header = table[0]
            if not header.strip().startswith("|"):
                header = "| " + " | ".join(cells) + " |"
            sep = "| " + " | ".join(["---"] * len(cells)) + " |"
            output.append(header)
            output.append(sep)
            output.extend(table[1:])
            continue
        output.append(line)
        i += 1

    return "\n".join(output) + ("\n" if text.endswith("\n") else "")


def convert_mermaid_blocks(text: str) -> str:
    pattern = re.compile(r"```mermaid\s*\n(.*?)\n```", re.DOTALL)

    def repl(match: re.Match[str]) -> str:
        body = match.group(1).strip()
        summary = "Flowchart note: Mermaid content is preserved as code so it can still be reviewed or manually converted in Feishu."
        return f"{summary}\n\n```text\n{body}\n```"

    return pattern.sub(repl, text)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)

    source = input_path.read_text(encoding="utf-8")
    fallback_title = input_path.stem.replace("-", " ").replace("_", " ").strip() or "Feishu Document"
    title = extract_title(source, fallback_title)

    prepared = keep_h1(source)
    prepared = normalize_code_fences(prepared)
    prepared = normalize_tables(prepared)
    prepared = convert_mermaid_blocks(prepared)

    output_path.write_text(prepared, encoding="utf-8")
    print(title)


if __name__ == "__main__":
    main()
