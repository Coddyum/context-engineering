# Rule — reports (docs/rapport/)

Referenced by `AGENTS.md` / `CLAUDE.md`.

## When

When the user asks for a **report** — an analysis of a feature, how X or Y works, an audit, an
investigation write-up — the agent writes it as a Markdown file, it does not dump the whole thing
into the chat.

## Where

`docs/rapport/<report-name>.md` (kebab-case name).

This folder is **git-ignored** (see `.gitignore`) — reports are working artifacts, not tracked source.

## Language & style

- Reports are written in **<REPORT_LANGUAGE>** — pick one and state it here. The original of this
  template writes them in French, because that is what the human reads; the doctrine itself stays
  in English. The point is that the choice is explicit, so the agent never has to guess.
- **Every compression mode is OFF** for reports: full, normal prose, no dropped articles. This
  overrides an active terse/caveman mode, for report content only.

> Why the exception: compression is worth it on the thousands of tokens an agent reads per session.
> A report is written once and read by a human, possibly months later — the tokens saved there are
> not worth the ambiguity bought.

## Discoverability — important

Git-ignored files are invisible to `git`-aware search (`rg`, `git grep` skip them), so agents often
"lose" earlier reports. To find them, do NOT rely on ripgrep — list the folder directly:

```
scripts/reports.sh list          # list existing reports
scripts/reports.sh new <name>    # create docs/rapport/<name>.md (French stub)
```

or plainly `ls docs/rapport/`. The `SessionStart` hook also prints existing reports at the start of
each Claude Code session.
