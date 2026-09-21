# Global rules — every machine, every repository

`~/.claude/CLAUDE.md`. Short on purpose: it is prepended to every session in every repo, so every
line here is paid for thousands of times. Anything project-specific belongs in that project's
`CLAUDE.md`, not in this file.

## Packages — pnpm only

**pnpm is the only package manager allowed.** `npm`, `npx`, `yarn` and `bun` are banned in every
repository, with no exception for a project's existing tooling.

| Instead of | Use |
| --- | --- |
| installing the locked tree | `pnpm install` |
| adding one package | `pnpm add <pkg>` |
| a clean CI install | `pnpm install --frozen-lockfile` |
| running a script | `pnpm <script>` |
| running a one-off binary | `pnpm dlx <bin>` |

A repository carrying a `package-lock.json` or a `yarn.lock` gets migrated to `pnpm-lock.yaml` —
it does not justify reaching for another manager "just this once".

## Packages — 14-day quarantine (every manager, every language)

**No version published less than 14 full days ago gets installed** — whatever the source: pnpm,
npm, yarn, bun, `pip` / `uv` / `poetry`, `go install` / `go get`, or any other manager, for any
language.

A supply-chain compromise is detected within hours to days. Waiting out the window lets the
registry pull the malicious version before it ever reaches the machine. Every headline npm
compromise of the last few years — the post-install crypto stealers, the hijacked maintainer
accounts — was caught and unpublished inside that window. The delay is the whole defence.

**If the resolved version is younger than 14 days, install the one before it** — the most recent
one that cleared the window. No exception, for any package, at any urgency.

Concretely:

- No install of a package whose resolved version is under 14 days old — including when it is
  `latest` that is fresh. Step back one version.
- **No mass update** (`pnpm update` with no argument, `pip install -U`, `go get -u`): it drags
  every dependency to its newest published version. Target one package at a time, at an exact
  version.
- No install without a lockfile: without one, everything resolves to `latest`.
- A version that existed and then disappeared from the registry does not get installed — npm
  unpublishes precisely what is found to be compromised.

Enforcement — automatic for JS, manual elsewhere:

- `minimumReleaseAge: 20160` (minutes = 14 days) and `saveExact: true` in the global pnpm config
  (`config/pnpm-config.yaml` here): pnpm resolves to the newest sufficiently-old version on its
  own, pinned exactly.
- `PreToolUse` hook on `Bash`: `hooks/block-fresh-packages.mjs`, blocking exit 2, **fails closed**
  (registry unreachable = refused). It covers JS only, and bans the other managers on the way
  past.
- **Python and Go have no automatic guard**: apply the 14-day rule by hand — check the publish
  date before installing, step back if it is too fresh.

## Pinned projects

Projects running real traffic pin every dependency exactly (no `^`, no `~`). Never reintroduce a
range into their `package.json`: a range is what reopens the door to an automatic upgrade.
