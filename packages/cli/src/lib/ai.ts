import fs from 'node:fs'
import path from 'node:path'
import { execa } from 'execa'
import pc from 'picocolors'
import { isNotFound } from '../config.js'
import { isOlderVersion } from './release-line.js'

export const DOCS_MCP_URL = 'https://spreecommerce.org/docs/mcp'
export const DOCS_MCP_SERVER_NAME = 'spree-docs'
export const AGENT_SKILLS_REPO = 'spree/agent-skills'
const AGENT_SKILLS_GIT_URL = `https://github.com/${AGENT_SKILLS_REPO}.git`

/**
 * Project-level MCP files of each coding agent that reads one. Claude Code and
 * Cursor share a format; VS Code names its root `servers` and needs `type`.
 */
const MCP_CONFIGS = [
  { file: '.mcp.json', root: 'mcpServers', entry: { type: 'http', url: DOCS_MCP_URL } },
  { file: '.cursor/mcp.json', root: 'mcpServers', entry: { url: DOCS_MCP_URL } },
  { file: '.vscode/mcp.json', root: 'servers', entry: { type: 'http', url: DOCS_MCP_URL } },
] as const

export type McpConfigOutcome = 'added' | 'present' | 'unreadable' | 'unwritable'

/**
 * Add the Spree docs MCP server to every agent's project config, keeping the
 * servers already listed there. A file that is not plain JSON (VS Code allows
 * comments) is reported as `unreadable` and left untouched — never rewritten.
 * A file that cannot be written is reported as `unwritable`; the others are
 * still updated.
 *
 * @param projectDir the project root
 * @return each config file's path with what happened to it
 */
export function addDocsMcpServer(projectDir: string): Record<string, McpConfigOutcome> {
  const outcomes: Record<string, McpConfigOutcome> = {}

  for (const { file, root, entry } of MCP_CONFIGS) {
    const filePath = path.join(projectDir, file)
    let config: Record<string, unknown> = {}
    try {
      config = JSON.parse(fs.readFileSync(filePath, 'utf-8'))
    } catch (error) {
      if (!isNotFound(error)) {
        outcomes[file] = 'unreadable'
        continue
      }
    }
    if (!isObject(config) || (config[root] !== undefined && !isObject(config[root]))) {
      outcomes[file] = 'unreadable'
      continue
    }

    const servers = (config[root] as Record<string, unknown> | undefined) ?? {}
    if (servers[DOCS_MCP_SERVER_NAME] !== undefined) {
      outcomes[file] = 'present'
      continue
    }

    config[root] = { ...servers, [DOCS_MCP_SERVER_NAME]: entry }
    try {
      fs.mkdirSync(path.dirname(filePath), { recursive: true })
      writeFileAtomically(filePath, `${JSON.stringify(config, null, 2)}\n`)
      outcomes[file] = 'added'
    } catch {
      outcomes[file] = 'unwritable'
    }
  }

  return outcomes
}

// Projects scaffolded before `@spree/docs` was a dependency have no local
// copy, so the section only points at one that is installed.
function docsSection(hasLocalDocs: boolean): string {
  const lines = [
    '## Searching the Spree docs',
    '',
    `The \`${DOCS_MCP_SERVER_NAME}\` MCP server (configured in \`.mcp.json\`, \`.cursor/mcp.json\` and`,
    '`.vscode/mcp.json`) searches the latest published Spree docs.',
  ]
  if (hasLocalDocs) {
    lines.push(
      'Use it when you do not know which page covers a topic, then read the page from',
      '`node_modules/@spree/docs/dist/`. The server can be ahead of the Spree version this',
      'project runs — when the two disagree, the local files are right for this project.',
    )
  } else {
    lines.push('Search it before relying on what you remember about Spree.')
  }
  lines.push('')
  return lines.join('\n')
}

function hasLocalDocs(projectDir: string): boolean {
  try {
    const pkg = JSON.parse(fs.readFileSync(path.join(projectDir, 'package.json'), 'utf-8'))
    return Boolean(pkg.dependencies?.['@spree/docs'] ?? pkg.devDependencies?.['@spree/docs'])
  } catch {
    return false
  }
}

/**
 * Append the docs-search section to each agent instructions file an agent
 * reads on its own: `AGENTS.md`, and `CLAUDE.md` unless it only imports
 * `AGENTS.md` (Claude Code reads CLAUDE.md alone). Files that already mention
 * the server are left as they are, and a file that cannot be written does
 * not stop the others.
 *
 * @param projectDir the project root
 * @return the files that were updated, and those that could not be
 */
export function addDocsSectionToAgentInstructions(projectDir: string): {
  updated: string[]
  failed: string[]
} {
  const updated: string[] = []
  const failed: string[] = []
  const section = docsSection(hasLocalDocs(projectDir))

  for (const file of ['AGENTS.md', 'CLAUDE.md']) {
    const filePath = path.join(projectDir, file)
    if (!fs.existsSync(filePath)) continue

    try {
      const content = fs.readFileSync(filePath, 'utf-8')
      if (content.includes(DOCS_MCP_SERVER_NAME)) continue
      if (file === 'CLAUDE.md' && /^@AGENTS\.md\s*$/m.test(content)) continue

      const separator = content.endsWith('\n\n') ? '' : content.endsWith('\n') ? '\n' : '\n\n'
      writeFileAtomically(filePath, `${content}${separator}${section}`)
      updated.push(file)
    } catch {
      failed.push(file)
    }
  }
  return { updated, failed }
}

/**
 * Runner for a one-off remote package. Yarn 1 has no `dlx`, and a lockfile
 * does not say which Yarn a project uses, so Yarn projects use `npx`, which
 * ships with every Node install.
 */
export function dlxCommand(packageManager: string): string[] {
  if (packageManager === 'pnpm') return ['pnpm', 'dlx']
  return ['npx', '--yes']
}

/**
 * The `skills` CLI arguments that install every Spree agent skill, from the
 * given release tag of `spree/agent-skills`, or from its main branch without one.
 */
export function installSkillsArgs(ref?: string): string[] {
  const source = ref ? `${AGENT_SKILLS_REPO}#${ref}` : AGENT_SKILLS_REPO
  return ['add', source, '--skill', '*', '--yes']
}

const RELEASE_TAG = /^v(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)$/

/**
 * The release of the Spree agent skills written for a Spree version: the
 * newest `v<version>` tag on the same minor line that is not newer than it.
 * The skills are tagged only when they change, so `v6.0.1` serves Spree 6.0.4
 * until a later 6.0 tag exists.
 *
 * @param spreeVersion the Spree version in npm spelling, e.g. `6.0.4`
 * @param tags the tags of `spree/agent-skills`
 * @return the tag, or undefined when no release covers that line yet
 */
export function agentSkillsRefFor(spreeVersion: string, tags: string[]): string | undefined {
  const line = spreeVersion.split('.').slice(0, 2).join('.')
  let newest: string | undefined
  for (const tag of tags) {
    const version = tag.match(RELEASE_TAG)?.[1]
    if (!version || version.split('.').slice(0, 2).join('.') !== line) continue
    if (isOlderVersion(spreeVersion, version)) continue
    if (newest === undefined || isOlderVersion(newest, version)) newest = version
  }
  return newest && `v${newest}`
}

/**
 * The release tag of the Spree agent skills for a Spree version, read from
 * GitHub. Undefined when no release covers it or the tags cannot be listed,
 * and the skills then come from the main branch.
 */
export async function resolveAgentSkillsRef(spreeVersion: string): Promise<string | undefined> {
  try {
    const { stdout } = await execa('git', ['ls-remote', '--tags', '--refs', AGENT_SKILLS_GIT_URL], {
      stdin: 'ignore',
      timeout: 30_000,
    })
    const tags = String(stdout ?? '')
      .split('\n')
      .map((line) => line.split('refs/tags/')[1]?.trim())
      .filter((tag): tag is string => Boolean(tag))
    return agentSkillsRefFor(spreeVersion, tags)
  } catch {
    return undefined
  }
}

/** The full command that runs the `skills` CLI with the given arguments. */
function skillsCommand(packageManager: string, args: readonly string[]): string[] {
  return [...dlxCommand(packageManager), 'skills', ...args]
}

// The failures in the `--json` output of `skills add`: one entry per skill,
// plus one for a failure that stopped the whole run, such as a failed clone.
function failedSkills(stdout: unknown): string[] {
  if (typeof stdout !== 'string') return []
  try {
    const results: unknown = JSON.parse(stdout)
    if (!Array.isArray(results)) return []
    return results
      .filter((result) => isObject(result) && result.status === 'failed')
      .map((result) =>
        [result.name, result.error].filter((part) => typeof part === 'string').join(': '),
      )
      .map((reason) => reason || 'unknown failure')
  } catch {
    return []
  }
}

// `--json` reports each skill's result, so a skill that failed to install is
// caught even when the run exits with code 0. A stalled download must fail
// rather than hang the command.
async function runSkills(
  projectDir: string,
  packageManager: string,
  args: readonly string[],
): Promise<unknown> {
  const [command, ...rest] = skillsCommand(packageManager, args)
  let stdout: unknown
  try {
    ;({ stdout } = await execa(command, [...rest, '--json'], {
      cwd: projectDir,
      stdin: 'ignore',
      timeout: 120_000,
    }))
  } catch (error) {
    const failures = failedSkills((error as { stdout?: unknown }).stdout)
    if (failures.length > 0) throw new Error(failures.join('\n'), { cause: error })
    throw error
  }
  const failures = failedSkills(stdout)
  if (failures.length > 0) throw new Error(failures.join('\n'))
  return stdout
}

// The names of the skills in the `--json` output of `skills add`: every skill
// the source has, whatever happened to it.
function reportedSkills(stdout: unknown): Set<string> {
  if (typeof stdout !== 'string') return new Set()
  try {
    const results: unknown = JSON.parse(stdout)
    if (!Array.isArray(results)) return new Set()
    return new Set(
      results
        .map((result) => (isObject(result) ? result.name : undefined))
        .filter((name): name is string => typeof name === 'string'),
    )
  } catch {
    return new Set()
  }
}

/**
 * Install every Spree agent skill for each coding agent the `skills` CLI
 * detects, without prompting. The skills-lock.json the `skills` CLI writes
 * records the release each skill came from, so `spree upgrade` can move them
 * with the server. Run again, it replaces the installed skills with that
 * release's, adds the ones it has that are missing, and removes the Spree
 * skills it no longer has. Skills from other sources are left alone.
 *
 * @param projectDir the project root
 * @param packageManager the project's package manager, which runs the `skills` CLI
 * @param ref the release tag from `resolveAgentSkillsRef`; the main branch without one
 * @return the obsolete Spree skills that could not be removed; empty when none are left
 */
export async function installAgentSkills(
  projectDir: string,
  packageManager: string,
  ref?: string,
): Promise<string[]> {
  const stdout = await runSkills(projectDir, packageManager, installSkillsArgs(ref))
  const obsolete = obsoleteSpreeAgentSkills(projectDir, ref, reportedSkills(stdout))
  if (obsolete.length === 0) return []
  // `skills remove` keeps a skill folder the developer has edited.
  const [command, ...rest] = skillsCommand(packageManager, ['remove', ...obsolete, '--yes'])
  try {
    await execa(command, rest, { cwd: projectDir, stdin: 'ignore', timeout: 120_000 })
  } catch {
    return obsolete
  }
  return obsoleteSpreeAgentSkills(projectDir, ref, reportedSkills(stdout))
}

/**
 * The Spree skills left behind by an install: the ones `skills-lock.json`
 * attributes to `spree/agent-skills` at another release than the one just
 * installed, and that the install did not report. The `skills` CLI merges a
 * release's skills into the lockfile, so a skill the release dropped keeps
 * its old entry. Both checks must agree, so a skill is never removed on the
 * strength of one of them, and nothing is removed when the install reported
 * no skills at all.
 *
 * @param ref the release tag just installed; the main branch without one
 * @param installed the skill names the install reported
 */
export function obsoleteSpreeAgentSkills(
  projectDir: string,
  ref: string | undefined,
  installed: ReadonlySet<string>,
): string[] {
  if (installed.size === 0) return []
  const skills = readSkillsLock(projectDir)
  return Object.entries(skills)
    .filter(
      ([name, entry]) =>
        isSpreeAgentSkill(entry) &&
        (typeof entry.ref === 'string' ? entry.ref : undefined) !== ref &&
        !installed.has(name),
    )
    .map(([name]) => name)
}

function normalizeSource(source: string): string {
  return source
    .trim()
    .toLowerCase()
    .replace(/^https?:\/\/github\.com\//, '')
    .replace(/(\.git)?\/?$/, '')
}

/**
 * Whether the project has Spree agent skills installed, read from the
 * `skills-lock.json` the `skills` CLI writes: a skill whose source is
 * `spree/agent-skills`. Skills from other sources are the developer's own.
 *
 * @param projectDir the project root
 * @return false when there are none or the lockfile is unreadable
 */
export function hasSpreeAgentSkills(projectDir: string): boolean {
  return Object.values(readSkillsLock(projectDir)).some(isSpreeAgentSkill)
}

// The `skills` entries of skills-lock.json; none when it is missing or unreadable.
function readSkillsLock(projectDir: string): Record<string, unknown> {
  try {
    const lock = JSON.parse(fs.readFileSync(path.join(projectDir, 'skills-lock.json'), 'utf-8'))
    return isObject(lock) && isObject(lock.skills) ? lock.skills : {}
  } catch {
    return {}
  }
}

function isSpreeAgentSkill(entry: unknown): entry is Record<string, unknown> {
  return (
    isObject(entry) &&
    typeof entry.source === 'string' &&
    normalizeSource(entry.source) === AGENT_SKILLS_REPO
  )
}

// Enough of the reason to name the cause without flooding the terminal.
const FAILURE_REASON_LINES = 10

// The SGR escape sequences that colour terminal output.
const ANSI_COLOR = new RegExp(`${String.fromCharCode(27)}\\[[0-9;]*m`, 'g')

/**
 * The warning for a failed `skills` run: the command to run by hand, then the
 * last lines of the reason, without colour codes.
 *
 * @param what what did not happen, e.g. `installed`
 */
export function skillsFailureMessage(
  what: string,
  packageManager: string,
  args: readonly string[],
  error: unknown,
): string {
  // Double quotes keep `*` from being globbed in POSIX shells, PowerShell and cmd.
  const command = skillsCommand(packageManager, args)
    .map((arg) => (arg === '*' ? '"*"' : arg))
    .join(' ')
  const reason = (error instanceof Error ? error.message : String(error))
    .replace(ANSI_COLOR, '')
    .split('\n')
    .map((line) => line.trimEnd())
    .filter(Boolean)
    .slice(-FAILURE_REASON_LINES)
    .join('\n')
  return `The Spree agent skills were not ${what}. Run ${pc.bold(command)} to try again.\n${reason}`
}

/**
 * The warning for Spree skills an install left behind because `skills remove`
 * failed: which ones, and the command that removes them.
 */
export function obsoleteSkillsMessage(packageManager: string, skills: readonly string[]): string {
  const command = skillsCommand(packageManager, ['remove', ...skills, '--yes']).join(' ')
  return `These Spree agent skills are not in the installed release: ${skills.join(', ')}. Run ${pc.bold(command)} to remove them.`
}

// These files hold the developer's own content, so a failed write must leave
// the original whole: write a sibling file, then rename it over the target.
// The sibling takes the original's permissions, so a private file stays private.
function writeFileAtomically(filePath: string, content: string): void {
  let mode: number | undefined
  if (fs.existsSync(filePath)) {
    // A rename replaces even a read-only file, so refuse those up front.
    fs.accessSync(filePath, fs.constants.W_OK)
    mode = fs.statSync(filePath).mode & 0o777
  }

  const temporaryPath = `${filePath}.${process.pid}.tmp`
  try {
    fs.writeFileSync(temporaryPath, content, { mode: mode ?? 0o666 })
    // The mode given on creation is narrowed by the umask; set it exactly.
    if (mode !== undefined) fs.chmodSync(temporaryPath, mode)
    fs.renameSync(temporaryPath, filePath)
  } catch (error) {
    fs.rmSync(temporaryPath, { force: true })
    throw error
  }
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}
