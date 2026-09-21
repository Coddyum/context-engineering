# Supply chain: the 14-day quarantine

One rule, enforced at three levels: **no package version published less than 14 full days ago gets
installed.** Every manager, every language, no exception, at any urgency.

If the version that would be installed is younger than 14 days, the one before it goes in — the most
recent that cleared the window.

Files: [`templates/shared/`](../templates/shared/).

---

## Why 14 days

A supply-chain compromise is detected within hours to days. The pattern is consistent across the
npm incidents of recent years: a maintainer account is taken over or a malicious version published,
someone notices the post-install script or the exfiltration within a day or two, and the registry
unpublishes it.

The window between publish and removal is the whole attack surface. Waiting it out means the
registry does the work for you: by the time your machine resolves the version, the malicious one is
already gone.

The cost is being two weeks behind on features you almost never need on day one. The benefit is that
the class of attack that hits fastest cannot reach you at all. On a project running real traffic
that trade is not close.

It applies **in full** to transitive dependencies, which is where these attacks actually land — the
compromised package is rarely the one you typed.

---

## What follows from it

- **No install of anything under 14 days old**, including when it is `latest` that is fresh. Step
  back one version.
- **No mass update.** `pnpm update` with no argument, `pip install -U`, `go get -u` — each drags
  every dependency to its newest published version. Target one package at a time, at an exact
  version.
- **No install without a lockfile.** Without one, everything resolves to `latest`.
- **A version that existed and then vanished from the registry does not get installed.** npm
  unpublishes precisely what is found to be compromised, so a gap in the version history is a
  signal, not an accident.
- **Exact pins, no ranges.** A `^` is a standing instruction to auto-upgrade at the next lockfile
  refresh, which is the one thing the quarantine exists to prevent.

---

## Three layers of enforcement

### 1. pnpm resolves correctly on its own

```yaml
# ~/Library/Preferences/pnpm/config.yaml
minimumReleaseAge: 20160   # minutes = 14 days
saveExact: true
```

pnpm refuses to resolve a version published more recently, and picks the newest one that *is* old
enough. Nothing to remember, nothing to type — the safe choice becomes the default choice, which is
the only kind of security control that survives a year.

### 2. A blocking hook, machine-wide

[`hooks/block-fresh-packages.mjs`](../templates/shared/hooks/block-fresh-packages.mjs), wired on
`PreToolUse(Bash)` in `~/.claude/settings.json`. User-level, not per-repo: a per-repo hook protects
the repos you remembered to configure, which is not the set that matters. The risky install is the
one you run in a scratch directory at 23:40 while chasing something else.

It parses the command, resolves what would actually be installed, and refuses on any of:

| Situation | Verdict |
| --- | --- |
| resolved version under 14 days old | blocked |
| version present in the registry's history but pulled | blocked |
| publish date unreadable, registry unreachable | **blocked** — fails closed |
| bare `update` / `upgrade` | blocked |
| install with no lockfile present | blocked |
| `--minimum-release-age=0` and friends | blocked |
| `npm` / `npx` / `yarn` / `bun` at all | blocked, with the pnpm equivalent printed |
| `install` / `ci` with a lockfile present | allowed — versions already pinned |

**It fails closed.** Registry unreachable, no publish date, version missing from the packument — all
refused. A guard that opens when it cannot see is one an attacker only has to blind.

Details worth stealing if you write your own:

- **An exact pin is judged on its own merits**, never on the dist-tag. Otherwise a version the
  registry has since pulled sails through on the strength of an unrelated `latest`.
- **Shell splitting respects quotes.** A naive split on `&&` turns `echo "... && npm i ..."` into
  what looks like a real invocation.
- **`cd x && pnpm install` is judged against `x`**, not the session directory — otherwise a
  lockfile one directory away reads as no lockfile at all.
- **A runner fetches only its first argument.** `pnpm dlx tsx script.ts` downloads `tsx`;
  `script.ts` is not a package name. An earlier verb-list approach let `npx tsx` through entirely.

Check it fires:

```bash
echo '{"tool_input":{"command":"npm install left-pad"},"cwd":"/tmp"}' \
  | node ~/.claude/hooks/block-fresh-packages.mjs; echo "exit=$?"   # expect exit=2
```

### 3. A repository guard for what gets copy-pasted

[`check-package-manager.sh`](../templates/next-frontend/scripts/check-package-manager.sh) refuses
`npm` / `npx` / `yarn` / `bun` anywhere a human or an agent would copy a command from: `package.json`
scripts, documentation, CI workflows, shell scripts.

It is not a style rule. Running `npm install` against a pnpm-locked repository resolves the tree
afresh instead of honouring `pnpm-lock.yaml` — walking straight past both the pins and the
quarantine.

Two details that came out of using it:

- **No exemption for markdown, ever.** An earlier version let a `.md` line name a banned command as
  long as it also named the pnpm replacement, so a migration table could live in `CLAUDE.md`. Wrong
  trade: documentation is the single most likely place for someone to copy a command from, so it is
  the last place that should contain one. The table was rewritten by intent instead ("to install the
  locked tree → `pnpm install`"), which reads better *and* removed the need for the exemption.
- **`npx` and `bunx` match on any argument**, with no verb list. Their first argument is not a verb,
  it is a package name: `npx tsx` downloads and executes a package just as much as `npm install`
  does.

---

## The gap, stated plainly

**Python and Go have no automatic guard here.** The hook covers JS only.

For `pip` / `uv` / `poetry` and `go install` / `go get`, the 14-day rule is applied by hand: check
the publish date before installing, step back if it is too fresh. Writing the equivalent guard for
PyPI and the Go module proxy is the obvious next thing, and it does not exist yet.

Saying so is more useful than implying coverage that is not there.

---

## Why pnpm only

Not a preference. A repository locked with pnpm and installed with npm gets a freshly resolved tree
instead of the locked one — which is exactly how a newly published compromised version gets in.
Mixing managers in one repository means the guarantees of whichever one you configured apply only
half the time.

One manager, one lockfile, one set of guarantees. A repository carrying a `package-lock.json` or a
`yarn.lock` gets migrated, not excepted.
