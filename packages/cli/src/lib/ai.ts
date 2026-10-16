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
  const [command, ...runnerArgs] = dlxCommand(packageManager)
  await execa(
    command,
    [...runnerArgs, 'skills', 'add', AGENT_SKILLS_REPO, '--skill', '*', '--yes'],
    // A stalled download must fail rather than hang the command.
    { cwd: projectDir, stdio: 'ignore', timeout: 120_000 },
  )
}

// These files hold the developer's own content, so a failed write must leave
// the original whole: write a sibling file, then rename it over the target.
function writeFileAtomically(filePath: string, content: string): void {
  // A rename replaces even a read-only file, so refuse those up front.
  if (fs.existsSync(filePath)) fs.accessSync(filePath, fs.constants.W_OK)

  const temporaryPath = `${filePath}.${process.pid}.tmp`
  try {
    fs.writeFileSync(temporaryPath, content)
    fs.renameSync(temporaryPath, filePath)
  } catch (error) {
    fs.rmSync(temporaryPath, { force: true })
    throw error
  }
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}
