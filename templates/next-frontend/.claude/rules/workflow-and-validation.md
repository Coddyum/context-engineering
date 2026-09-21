# Rule — workflow & validation

Referenced by `CLAUDE.md`.

## Mandatory workflow

**Changes are written directly into the files** with the edit tools. Never paste code blocks or
diffs into the chat. Zero code proposals in the conversation, no exception.

Flow:

1. If clarification is needed, ask **one targeted question** — then wait for the answer.
2. Apply the changes directly in the files.
3. Wait for the user's validation (yes / no / correction) before continuing.

**Forbidden**: pasting code into the chat in any form (markdown blocks, inline code, textual
diffs). If there is an urge to "show" the code, write it in the file instead.

> This is the single biggest per-session token lever on the frontend side. Code shown in chat is
> paid for twice — once as output, once again as input on every subsequent turn of the
> conversation — and then written to the file anyway. The file is the deliverable; the chat is
> not a draft area.

## Never without validation

- Creating, modifying or deleting a file outside the current task's scope
- Refactoring existing code not directly related to the task
- Adding a dependency
- Renaming files or folders
- Touching configuration (`next.config`, `tailwind.config`, `tsconfig`…)

## Expected responses

- **No code in the chat** — changes go straight into the files.
- **No over-explaining** — clean code speaks for itself.
- If an architecture decision is ambiguous, ask **one** targeted question before coding.
- Never propose a library absent from the stack.
