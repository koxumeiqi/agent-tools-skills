---
name: sync-feishu-docs
description: Sync Markdown, articles, specs, notes, and other written documents to Feishu by using the official lark-cli. Use when the user asks to "同步文档到飞书", "同步飞书", "发到飞书", "上传到飞书文档", "同步到飞书知识库", or similar wording that means publishing or updating content in Feishu Docs, Drive, or Wiki. This skill requires a working Feishu CLI environment and should only run when lark-cli is already installed and authenticated.
---

# Sync Feishu Docs

Use this skill to publish local Markdown content into Feishu through the official `lark-cli`.

Prefer this skill when the user wants a real Feishu document outcome, not just a local `.md` file.

## Preconditions

Verify all of the following before syncing:

1. The official `lark-cli` is available in the current environment.
2. `lark-cli auth status --verify` reports `verified: true` and at least one usable identity.
3. The current environment can reach Feishu endpoints.

If any check fails, stop and report the missing prerequisite instead of attempting sync.

### Windows CLI discovery

On Windows, first try `where.exe lark-cli`. If that fails, check the npm global shim directly:

```powershell
Test-Path "$env:APPDATA\npm\lark-cli.cmd"
```

If the shim exists, use its full path for commands:

```powershell
& "$env:APPDATA\npm\lark-cli.cmd" --help
```

The current shell may not have refreshed `PATH` even after the CLI was installed. Do not stop just because `where.exe lark-cli` fails when the shim exists.

### Official CLI package

Use the official `@larksuite/cli` package. Do not install the npm package named `lark-cli`; `lark-cli@0.1.0` is not the official Feishu CLI and may not expose a working command.

Official installation command:

```powershell
cmd /c npx.cmd @larksuite/cli@latest install
```

After installation, initialize and authenticate interactively if needed:

```powershell
lark-cli config init --new
lark-cli auth login
```

If PowerShell cannot find the command yet, use:

```powershell
& "$env:APPDATA\npm\lark-cli.cmd" config init --new
& "$env:APPDATA\npm\lark-cli.cmd" auth login
```

### Auth status interpretation

`lark-cli auth status --verify` may report a user identity with `status: "needs_refresh"` while the top-level `verified` field is `true`. Treat this as usable when the response says the user identity will refresh automatically on the next API call.

Stop only when authentication is not verified, no usable `user` or `bot` identity is available, or the command reports an expired/non-refreshable token.

## Trigger Phrases

Treat the following as clear triggers:

- "同步文档到飞书"
- "同步飞书"
- "发到飞书"
- "上传到飞书文档"
- "同步到飞书知识库"
- "把这篇文章放到飞书"
- "把这个 markdown 发到飞书"

## Workflow

### 1. Choose the Feishu target type

Pick the simplest target that satisfies the request:

- Use `markdown +create` when the user only asked to put the content into Feishu Drive or did not specify a Wiki node.
- Use `docs +create --api-version v2` when the user explicitly wants a Feishu Doc or wants the content created under a Wiki space or Wiki node.
- Use update flows only when the user explicitly asks to overwrite or patch an existing Feishu document.

Default target:

- If the user did not specify a destination, publish to the user's personal Feishu space first.

### 2. Determine the document title

Do not default to the local filename when a better title is available.

Use this title priority:

1. User-specified title
2. The article's top-level title from content
3. A clean inferred title from the first heading
4. Filename only as a last resort

When syncing a Markdown article, extract the first H1 (`# Title`) and use that as the Feishu document title unless the user explicitly asked for another title.

If the content does not contain a usable H1, create a concise title before upload.

## 3. Normalize Markdown for Feishu

Feishu accepts Markdown, but the rendered result is better when the source is normalized first. Always preprocess the source before sync.

Run the bundled script:

```powershell
& 'C:\Users\myz03\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' `
  '<skill-dir>\scripts\prepare_feishu_markdown.py' `
  --input '<source-md>' `
  --output '<prepared-md>'
```

The script is responsible for:

- Extracting the document title from the first H1
- Removing a duplicate H1 when the title will be sent separately
- Normalizing fenced code blocks
- Normalizing Markdown tables where recovery is obvious
- Converting Mermaid blocks into a Feishu-friendly fallback
- Leaving ordinary headings, lists, and paragraphs intact

## 4. Format rules to enforce

### Title

- Use the article title, not the source filename, unless the user explicitly wants the filename.
- When creating the remote doc, send the title separately through the CLI flag.

### Code blocks

- Preserve fenced code blocks.
- Ensure fences are triple backticks.
- Keep the info string when present, for example ` ```python `.
- Do not flatten code blocks into paragraphs.

### Tables

- Preserve standard pipe tables.
- Add a separator row when the source table is malformed but recoverable.
- If a table is too irregular to render safely, convert it to a bullet list and mention that conversion in the final response.

### Flowcharts and Mermaid

Feishu document sync should not be assumed to render raw Mermaid automatically.

Default behavior:

- Keep the original Mermaid body in a fenced code block so the logic is preserved.
- Insert a short plain-language summary directly before it.
- If the user explicitly wants a polished Feishu-native visual result, explain that Mermaid may require a later render-to-image or manual in-doc conversion step.

Do not silently drop Mermaid content.

### Callouts and rich blocks

- Convert unsupported custom block syntaxes into plain headings, blockquotes, or bullet lists.
- Prefer readable degradation over brittle formatting.

## 5. Command execution rules

When using `@file` style Feishu CLI arguments, prefer `cmd /c` instead of a raw PowerShell command, because PowerShell treats `@...` specially. In PowerShell, piping text through `lark-cli.cmd` can still corrupt Chinese characters because the Windows shim and console code page may replace non-ASCII text with `?`.

For Chinese or other non-ASCII Markdown on Windows, prefer calling the native CLI executable from a Python subprocess and writing UTF-8 bytes to stdin:

```powershell
$env:PYTHONIOENCODING = 'utf-8'
& '<python.exe>' -c "import pathlib, subprocess, sys; exe=r'$env:APPDATA\npm\node_modules\@larksuite\cli\bin\lark-cli.exe'; data=pathlib.Path('prepared.md').read_bytes(); r=subprocess.run([exe,'docs','+create','--api-version','v2','--as','user','--title','Document Title','--content','-'], input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE); sys.stdout.write(r.stdout.decode('utf-8','replace')); sys.stderr.write(r.stderr.decode('utf-8','replace')); sys.exit(r.returncode)"
```

Use `--dry-run` with the same subprocess pattern when debugging. The dry-run body should show real Chinese text, not `????`.

PowerShell stdin is acceptable only for ASCII-heavy documents:

```powershell
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Get-Content -Raw -Encoding UTF8 '.\prepared.md' |
  & "$env:APPDATA\npm\lark-cli.cmd" docs +create `
    --api-version v2 `
    --as user `
    --title 'Document Title' `
    --content -
```

The explicit UTF-8 output settings are required on Windows. Without them, PowerShell can replace non-ASCII characters with `?` while piping to stdin, producing remote Feishu documents full of question marks even when the local Markdown is valid UTF-8.

Use Drive-native Markdown upload when the user wants a Markdown file in Drive rather than a Feishu Doc:

```cmd
cmd /c C:\path\to\lark-cli.cmd markdown +create --as user --name article.md --file .\prepared.md
```

Avoid this pattern in PowerShell unless you are certain it is being passed to `cmd.exe` without PowerShell parsing:

```cmd
cmd /c C:\path\to\lark-cli.cmd docs +create --api-version v2 --as user --title "Document Title" --markdown @.\prepared.md
```

Current official CLI versions may require `docs +create --api-version v2 --content` even when help text mentions `--markdown`. If `--markdown` fails with `--content is required`, retry with `--content -` and stdin.

Run from the directory containing the prepared Markdown file so relative paths work.

If `Get-Content` previews Chinese text as mojibake in the terminal, do not assume the file is corrupt. Prefer `Get-Content -Raw -Encoding UTF8` for upload and verify by the created document result.

## 7. Post-sync self-review

After creating or updating a Feishu document, verify the remote result before reporting success.

### API content review

Fetch the created document and inspect the server-side content:

```powershell
& "$env:APPDATA\npm\lark-cli.cmd" docs +fetch `
  --api-version v2 `
  --as user `
  --doc '<created-doc-url>'
```

The remote content must satisfy all of these checks:

- The document title or first visible title contains the intended title, not `Untitled`.
- Expected Chinese phrases from the source are present.
- No obvious mojibake markers appear, especially `????`, `æ`, `å`, or `Ñ` sequences in Chinese text.
- Markdown table separator rows are not present as data cells such as `<p>---</p>`.
- Mermaid content is preserved in readable fenced-code form or another explicitly chosen fallback.

If any check fails, fix the local preprocessing or upload method and sync again. Common fixes:

- For `????` output, re-upload using explicit UTF-8 PowerShell output settings before piping to `--content -`.
- For `Untitled`, keep the H1 in the Markdown body and pass `--title`; then verify whether `<title>` was set in `docs +fetch`.
- For table rows containing `---`, fix preprocessing so legal Markdown separator rows are not duplicated as table body rows.

### Playwright visual review

Use Playwright/browser review after API review when the user asks for visual confirmation or the task involves formatting quality. Open the created Feishu URL and check the visible page for:

- Correct visible title.
- Normal Chinese rendering, not `????` or mojibake.
- Tables do not include separator rows as visible data.
- Mermaid fallback/code blocks remain readable.

If the in-app browser is redirected to Feishu login and cannot inspect the document, state that visual browser review was blocked by login state, then rely on API review. When a logged-in browser profile is available, use it for the visual review.

## 8. Publishing defaults

For a new sync where the user did not specify destination details:

- Prefer `--as user`
- Prefer personal space
- Prefer a new document rather than overwriting an existing one

If the user wants a knowledge-base destination:

- Use `docs +create --api-version v2`
- Use `--wiki-space my_library` only for the user's personal library
- Use `--wiki-node` or a specific wiki destination only when the user provides or confirms it

## 9. Report back after sync

After a successful sync, always return:

- The final Feishu title used
- The sync target type used: Drive Markdown or Feishu Doc
- The resulting Feishu URL
- Any formatting degradations that occurred, such as Mermaid preserved as code or malformed tables converted to lists
- The self-review result, including whether API review passed and whether Playwright visual review passed or was blocked by login state

## Resources

### scripts/

- `prepare_feishu_markdown.py`
  Purpose: preprocess Markdown into a Feishu-friendly version and print the resolved title.

### references/

- `formatting-rules.md`
  Purpose: detailed conversion rules for Markdown, tables, code blocks, and Mermaid content.
