#!/usr/bin/env node
// PreToolUse(Bash) guard enforcing two package rules on every repo:
//
//   1. pnpm is the only package manager. npm / npx / yarn / bun are refused
//      and mapped to their pnpm equivalent.
//   2. No package whose selected version was published less than
//      MIN_AGE_DAYS ago may be installed.
//
// Rationale for the quarantine: supply-chain compromises are caught within
// hours to days of the malicious publish. A waiting window means a hijacked
// release is pulled from the registry before this machine can resolve it.
//
// Policy:
//   - named specs (npm i x, pnpm add x@1.2.3, npx x, yarn add x, bun add x)
//     -> resolve the version that would be installed, block if too fresh
//   - bare `update` / `upgrade` -> blocked outright (mass auto-update is the
//     exact vector this rule exists to close)
//   - bare `install` / `ci` with a lockfile present -> allowed (versions were
//     already pinned)
//   - bare `install` with no lockfile -> blocked (resolves to latest)
//   - explicit bypass flags (--minimum-release-age=0 and friends) -> blocked
//   - registry unreachable -> blocked (fail closed)

import { readFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { get } from 'node:https'

const MIN_AGE_DAYS = 14
const MIN_AGE_MS = MIN_AGE_DAYS * 24 * 60 * 60 * 1000
const FETCH_TIMEOUT_MS = 8000

const INSTALL_VERBS = new Set(['i', 'in', 'ins', 'install', 'add', 'ci', 'create'])
const UPDATE_VERBS = new Set(['update', 'up', 'upgrade', 'upgrade-interactive'])
// Runners that FETCH a package before running it. `pnpm exec` is deliberately
// absent: it runs a binary already installed locally, so there is nothing to
// vet — and treating its arguments as package names blocks ordinary commands.
const RUNNERS = new Set(['dlx', 'x'])
const MANAGERS = new Set(['npm', 'pnpm', 'yarn', 'bun', 'npx', 'corepack'])
const BANNED_MANAGERS = new Set(['npm', 'npx', 'yarn', 'bun'])

/** pnpm equivalent for the banned invocation, so the fix is one copy-paste. */
function pnpmEquivalent(mgr, verb, rest) {
  const tail = rest.length ? ` ${rest.join(' ')}` : ''
  if (mgr === 'npx') return `pnpm dlx${tail ? ` ${[verb, ...rest].join(' ')}` : ` ${verb}`}`.trim()
  if (RUNNERS.has(verb)) return `pnpm dlx${tail}`
  if (verb === 'ci') return 'pnpm install --frozen-lockfile'
  if (verb === 'install' || verb === 'i' || verb === 'add') return rest.length ? `pnpm add${tail}` : 'pnpm install'
  if (UPDATE_VERBS.has(verb)) return `pnpm update${tail}`
  if (verb === 'run' || verb === 'test' || verb === 'start') return `pnpm ${verb}${tail}`
  return `pnpm ${[verb, ...rest].filter(Boolean).join(' ')}`.trim()
}
const LOCKFILES = ['package-lock.json', 'pnpm-lock.yaml', 'yarn.lock', 'bun.lock', 'bun.lockb', 'npm-shrinkwrap.json']

function block(reason) {
  process.stderr.write(`[package guard] BLOCKED\n${reason}\n`)
  process.exit(2)
}

function allow() {
  process.exit(0)
}

/**
 * Split a shell line into the commands it chains together, ignoring separators
 * that sit inside quotes. A naive split turns `echo "... && npm i ..."` into a
 * fragment that reads as a real npm invocation.
 */
function splitCommands(line) {
  const parts = []
  let buf = ''
  let quote = null

  for (let i = 0; i < line.length; i++) {
    const ch = line[i]

    if (quote) {
      buf += ch
      if (ch === '\\' && quote === '"') buf += line[++i] ?? ''
      else if (ch === quote) quote = null
      continue
    }
    if (ch === '"' || ch === "'") {
      quote = ch
      buf += ch
      continue
    }
    if (ch === '\\') {
      buf += ch + (line[++i] ?? '')
      continue
    }
    if (ch === '\n' || ch === ';' || ch === '|' || ch === '&') {
      // consume the twin of && and ||
      if ((ch === '&' || ch === '|') && line[i + 1] === ch) i++
      parts.push(buf)
      buf = ''
      continue
    }
    buf += ch
  }
  parts.push(buf)

  return parts.map((s) => s.trim()).filter(Boolean)
}

/** Tokenise, dropping quotes; good enough for install invocations. */
function tokenise(cmd) {
  const out = []
  const re = /"([^"]*)"|'([^']*)'|(\S+)/g
  let m
  while ((m = re.exec(cmd)) !== null) out.push(m[1] ?? m[2] ?? m[3])
  return out
}

/** Strip leading env assignments and `sudo`, so `FOO=1 npm i x` still matches. */
function stripPrefix(tokens) {
  let i = 0
  while (i < tokens.length && (/^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[i]) || tokens[i] === 'sudo' || tokens[i] === 'command')) i++
  return tokens.slice(i)
}

/** Parse `@scope/name@range` / `name@range` into its two halves. */
function parseSpec(spec) {
  if (spec.startsWith('@')) {
    const at = spec.indexOf('@', 1)
    return at === -1 ? { name: spec, range: '' } : { name: spec.slice(0, at), range: spec.slice(at + 1) }
  }
  const at = spec.indexOf('@')
  return at === -1 ? { name: spec, range: '' } : { name: spec.slice(0, at), range: spec.slice(at + 1) }
}

/** A spec that does not resolve through the npm registry is out of scope. */
function isRegistrySpec(name, range) {
  if (!name || name.startsWith('-')) return false
  if (/^[./~]/.test(name) || name.includes('://')) return false
  if (/^(file|link|git|github|https?|npm|workspace|catalog|portal|patch):/.test(range)) return false
  if (/[/#]/.test(range)) return false
  return /^(@[a-z0-9._~-]+\/)?[a-z0-9._~-]+$/i.test(name)
}

function fetchPackument(name) {
  const url = `https://registry.npmjs.org/${name.replace('/', '%2F')}`
  return new Promise((resolve, reject) => {
    const req = get(url, { headers: { accept: 'application/json' } }, (res) => {
      if (res.statusCode !== 200) {
        res.resume()
        reject(new Error(`HTTP ${res.statusCode}`))
        return
      }
      let body = ''
      res.setEncoding('utf8')
      res.on('data', (c) => (body += c))
      res.on('end', () => {
        try {
          resolve(JSON.parse(body))
        } catch (e) {
          reject(e)
        }
      })
    })
    req.setTimeout(FETCH_TIMEOUT_MS, () => req.destroy(new Error('timeout')))
    req.on('error', reject)
  })
}

/**
 * Version that would actually land on disk. An exact pin is judged on its own
 * merits — never on the dist-tag, or a version the registry has since pulled
 * would be waved through on the strength of an unrelated `latest`. Anything
 * else (range, tag, nothing) resolves to the dist-tag, which is the freshest
 * thing the manager could pick.
 */
function selectedVersion(doc, range) {
  const tags = doc['dist-tags'] ?? {}
  if (!range) return { version: tags.latest }
  if (/^\d+\.\d+\.\d+/.test(range)) {
    if (doc.versions?.[range]) return { version: range }
    // Present in `time` but gone from `versions`: the registry unpublished it,
    // which is exactly what npm does to a compromised release.
    if (doc.time?.[range]) return { version: range, unpublished: true }
    return { version: null }
  }
  if (tags[range]) return { version: tags[range] }
  return { version: tags.latest }
}

async function checkPackage(name, range) {
  let doc
  try {
    doc = await fetchPackument(name)
  } catch (e) {
    return { name, verdict: 'unverifiable', detail: e.message }
  }
  const { version, unpublished } = selectedVersion(doc, range)
  if (!version) return { name, verdict: 'unverifiable', detail: 'version absent from the registry' }
  if (unpublished) return { name, version, verdict: 'unpublished', published: doc.time?.[version] }

  const published = doc.time?.[version]
  if (!published) return { name, version, verdict: 'unverifiable', detail: 'no publish date on the registry' }

  const ageMs = Date.now() - new Date(published).getTime()
  const ageDays = ageMs / (24 * 60 * 60 * 1000)
  if (ageMs < MIN_AGE_MS) return { name, version, verdict: 'too-fresh', ageDays, published }
  return { name, version, verdict: 'ok', ageDays }
}

function hasLockfile(cwd) {
  return LOCKFILES.some((f) => existsSync(join(cwd, f)))
}

async function main() {
  let payload = ''
  for await (const chunk of process.stdin) payload += chunk

  let input
  try {
    input = JSON.parse(payload)
  } catch {
    allow()
  }

  const command = input?.tool_input?.command
  if (typeof command !== 'string' || !command.trim()) allow()
  const cwd = input?.cwd || process.cwd()

  const targets = []
  // `cd x && pnpm install` must be judged against x, not against the session
  // cwd, or a lockfile one directory away reads as no lockfile at all.
  let effectiveCwd = cwd

  for (const raw of splitCommands(command)) {
    let tokens = stripPrefix(tokenise(raw))
    if (!tokens.length) continue

    if (tokens[0] === 'cd' && tokens[1]) {
      const target = tokens[1].replace(/^~(?=\/|$)/, process.env.HOME ?? '~')
      effectiveCwd = target.startsWith('/') ? target : join(effectiveCwd, target)
      continue
    }

    // `corepack pnpm add x` behaves as `pnpm add x`
    if (tokens[0] === 'corepack' && MANAGERS.has(tokens[1])) tokens = tokens.slice(1)

    const mgr = tokens[0]
    if (!MANAGERS.has(mgr)) continue

    const bypass = tokens.find((t) => /^--(minimum-release-age|min-release-age)(=|$)/.test(t))
    if (bypass) block(`\`${raw}\`\nThe ${bypass} flag disables the ${MIN_AGE_DAYS}-day quarantine. Refused.`)

    const isNpxBinary = mgr === 'npx'
    const verb = isNpxBinary ? 'npx' : tokens[1]
    const args = tokens.slice(isNpxBinary ? 1 : 2).filter((t) => !t.startsWith('-'))

    if (BANNED_MANAGERS.has(mgr)) {
      const rest = tokens.slice(isNpxBinary ? 2 : 2)
      block(
        `\`${raw}\`\n${mgr} is banned here: pnpm is the only package manager allowed, in every repository.\n\nEquivalent:\n  ${pnpmEquivalent(mgr, isNpxBinary ? tokens[1] ?? '' : verb ?? '', rest)}`,
      )
    }

    if (!isNpxBinary && UPDATE_VERBS.has(verb) && args.length === 0) {
      block(
        `\`${raw}\`\nMass update refused: it resolves every dependency to the latest published version, including ones younger than ${MIN_AGE_DAYS} days.\nTarget packages one at a time, at an exact version.`,
      )
    }

    const isInstall = INSTALL_VERBS.has(verb)
    const isRunner = isNpxBinary || RUNNERS.has(verb)
    if (!isInstall && !isRunner && !UPDATE_VERBS.has(verb)) continue

    if (isInstall && args.length === 0) {
      if (verb === 'ci' || hasLockfile(effectiveCwd)) continue // versions already pinned by the lockfile
      block(`\`${raw}\`\nInstall with no lockfile: every dependency resolves to the latest published version. Refused.`)
    }

    // A runner fetches its first argument only; the rest are the binary's own
    // arguments and must not be mistaken for package names.
    for (const arg of isRunner ? args.slice(0, 1) : args) {
      const { name, range } = parseSpec(arg)
      if (isRegistrySpec(name, range)) targets.push({ raw, name, range })
    }
  }

  if (!targets.length) allow()

  const results = await Promise.all(targets.map((t) => checkPackage(t.name, t.range)))

  const fresh = results.filter((r) => r.verdict === 'too-fresh')
  if (fresh.length) {
    const lines = fresh.map(
      (r) => `  - ${r.name}@${r.version} published ${r.ageDays.toFixed(1)} days ago (${r.published})`,
    )
    block(
      `Version(s) inside the ${MIN_AGE_DAYS}-day quarantine:\n${lines.join('\n')}\n\nA supply-chain compromise is caught within hours to days. Wait the window out, or pin an earlier version already at least ${MIN_AGE_DAYS} days old.`,
    )
  }

  const pulled = results.filter((r) => r.verdict === 'unpublished')
  if (pulled.length) {
    const lines = pulled.map((r) => `  - ${r.name}@${r.version} (published ${r.published}, pulled since)`)
    block(
      `Version(s) pulled from the registry:\n${lines.join('\n')}\n\nnpm unpublishes a version precisely when it is compromised. A version that existed and then vanished does not get installed.`,
    )
  }

  const unknown = results.filter((r) => r.verdict === 'unverifiable')
  if (unknown.length) {
    const lines = unknown.map((r) => `  - ${r.name} : ${r.detail}`)
    block(
      `Publish age unverifiable:\n${lines.join('\n')}\n\nThe rule fails closed: with no publish date, the ${MIN_AGE_DAYS} days cannot be guaranteed.`,
    )
  }

  allow()
}

main().catch((e) => {
  process.stderr.write(`[package guard] internal error: ${e?.message ?? e}\n`)
  process.exit(2)
})
