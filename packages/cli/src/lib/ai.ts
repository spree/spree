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

export type McpConfigOutcome = 'added' | 'present' | 'unreadable'

/**
 * Add the Spree docs MCP server to every agent's project config, keeping the
 * servers already listed there. A file that is not plain JSON (VS Code allows
 * comments) is reported as `unreadable` and left untouched — never rewritten.
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
    fs.mkdirSync(path.dirname(filePath), { recursive: true })
    fs.writeFileSync(filePath, `${JSON.stringify(config, null, 2)}\n`)
    outcomes[file] = 'added'
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
 * Append the docs-search section to the project's agent instructions
 * (`AGENTS.md`, or `CLAUDE.md` in projects older than it), unless they
 * already mention the server.
 *
 * @param projectDir the project root
 * @return the file that was updated, or null when none needed it
 */
export function addDocsSectionToAgentInstructions(projectDir: string): string | null {
  for (const file of ['AGENTS.md', 'CLAUDE.md']) {
    const filePath = path.join(projectDir, file)
    if (!fs.existsSync(filePath)) continue

    const content = fs.readFileSync(filePath, 'utf-8')
    if (content.includes(DOCS_MCP_SERVER_NAME)) return null

    const separator = content.endsWith('\n\n') ? '' : content.endsWith('\n') ? '\n' : '\n\n'
    fs.writeFileSync(filePath, `${content}${separator}${docsSection(hasLocalDocs(projectDir))}`)
    return file
  }
  return null
}

/** Runner for a one-off remote package (`npx`, `pnpm dlx`, `yarn dlx`). */
export function dlxCommand(packageManager: string): string[] {
  if (packageManager === 'npm') return ['npx', '--yes']
  return [packageManager, 'dlx']
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

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}
