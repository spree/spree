import fs from 'node:fs'
import path from 'node:path'
import { execa } from 'execa'
import { isNotFound } from '../config.js'

export const DOCS_MCP_URL = 'https://spreecommerce.org/docs/mcp'
export const DOCS_MCP_SERVER_NAME = 'spree-docs'
export const AGENT_SKILLS_REPO = 'spree/agent-skills'

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

/** The `skills` CLI arguments that install every Spree agent skill. */
export const INSTALL_SKILLS_ARGS = ['add', AGENT_SKILLS_REPO, '--skill', '*', '--yes']

/**
 * The `skills` CLI arguments that update the named skills to the newest
 * version on the main branch of their repository, for the agents they are
 * already installed for. Skills the developer removed stay removed.
 */
export function updateSkillsArgs(skills: string[]): string[] {
  return ['update', '--project', '--yes', ...skills]
}

/** The full command that runs the `skills` CLI with the given arguments. */
export function skillsCommand(packageManager: string, args: string[]): string[] {
  return [...dlxCommand(packageManager), 'skills', ...args]
}

async function runSkills(
  projectDir: string,
  packageManager: string,
  args: string[],
): Promise<void> {
  const [command, ...rest] = skillsCommand(packageManager, args)
  // Output is captured, not shown, so a failure can report the CLI's reason.
  // A stalled download must fail rather than hang the command.
  await execa(command, rest, { cwd: projectDir, stdin: 'ignore', timeout: 120_000 })
}

/**
 * Install every Spree agent skill for each coding agent the `skills` CLI
 * detects, without prompting.
 *
 * @param projectDir the project root
 * @param packageManager the project's package manager, which runs the `skills` CLI
 */
export async function installAgentSkills(
  projectDir: string,
  packageManager: string,
): Promise<void> {
  await runSkills(projectDir, packageManager, INSTALL_SKILLS_ARGS)
}

/**
 * Update the given Spree agent skills from the main branch of
 * `spree/agent-skills`, without prompting.
 *
 * @param projectDir the project root
 * @param packageManager the project's package manager, which runs the `skills` CLI
 * @param skills the installed Spree skills, from {@link installedSpreeSkills}
 */
export async function updateAgentSkills(
  projectDir: string,
  packageManager: string,
  skills: string[],
): Promise<void> {
  await runSkills(projectDir, packageManager, updateSkillsArgs(skills))
}

function normalizeSource(source: string): string {
  return source
    .trim()
    .toLowerCase()
    .replace(/^https?:\/\/github\.com\//, '')
    .replace(/(\.git)?\/?$/, '')
}

/**
 * The Spree agent skills a project has installed, read from the
 * `skills-lock.json` the `skills` CLI writes: the skills whose source is
 * `spree/agent-skills`. Skills from other sources are the developer's own.
 *
 * @param projectDir the project root
 * @return the skill names, [] when there are none or the lockfile is unreadable
 */
export function installedSpreeSkills(projectDir: string): string[] {
  try {
    const lock = JSON.parse(fs.readFileSync(path.join(projectDir, 'skills-lock.json'), 'utf-8'))
    if (!isObject(lock) || !isObject(lock.skills)) return []
    return Object.entries(lock.skills)
      .filter(
        ([, entry]) =>
          isObject(entry) &&
          typeof entry.source === 'string' &&
          normalizeSource(entry.source) === AGENT_SKILLS_REPO,
      )
      .map(([name]) => name)
  } catch {
    return []
  }
}

/**
 * The warning for a failed `skills` run: the command to run by hand, then the
 * CLI's own reason (its stderr) rather than execa's generic summary.
 *
 * @param what what did not happen, e.g. `installed`
 */
export function skillsFailureMessage(
  what: string,
  packageManager: string,
  args: string[],
  error: unknown,
): string {
  const command = skillsCommand(packageManager, args)
    .map((arg) => (arg === '*' ? `'*'` : arg))
    .join(' ')
  const stderr = (error as { stderr?: unknown } | undefined)?.stderr
  const reason =
    (typeof stderr === 'string' && stderr.trim()) ||
    (error instanceof Error ? error.message : String(error))
  return `The Spree agent skills were not ${what}. Run ${command} to try again.\n${reason}`
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
