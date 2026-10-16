import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { execa } from 'execa'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { addAi } from '../src/commands/add.js'
import type { ProjectContext } from '../src/types.js'

vi.mock('execa', () => ({ execa: vi.fn(async () => ({})) }))

const URL = 'https://spreecommerce.org/docs/mcp'

describe('addAi', () => {
  let projectDir: string

  function ctx(): ProjectContext {
    return { mode: 'docker', projectDir, port: 3000 }
  }

  function read(file: string): string {
    return fs.readFileSync(path.join(projectDir, file), 'utf-8')
  }

  function write(file: string, content: string): void {
    fs.mkdirSync(path.dirname(path.join(projectDir, file)), { recursive: true })
    fs.writeFileSync(path.join(projectDir, file), content)
  }

  beforeEach(() => {
    projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-add-ai-'))
    write('docker-compose.yml', 'services: {}\n')
    vi.mocked(execa).mockClear()
  })

  afterEach(() => {
    fs.rmSync(projectDir, { recursive: true, force: true })
  })

  it('connects each coding agent to the docs MCP server', async () => {
    expect(await addAi(ctx(), { skills: false, mcp: true, quiet: true })).toBe(true)

    expect(JSON.parse(read('.mcp.json'))).toEqual({
      mcpServers: { 'spree-docs': { type: 'http', url: URL } },
    })
    expect(JSON.parse(read('.cursor/mcp.json'))).toEqual({
      mcpServers: { 'spree-docs': { url: URL } },
    })
    expect(JSON.parse(read('.vscode/mcp.json'))).toEqual({
      servers: { 'spree-docs': { type: 'http', url: URL } },
    })
  })

  // Existing projects already list their own servers — adding ours must not
  // drop them, and re-running must not duplicate or rewrite ours.
  it('keeps the servers a project already lists and is safe to re-run', async () => {
    const own = { mcpServers: { github: { url: 'https://example.com/mcp' } }, other: true }
    write('.mcp.json', JSON.stringify(own))

    await addAi(ctx(), { skills: false, mcp: true, quiet: true })
    const once = read('.mcp.json')
    await addAi(ctx(), { skills: false, mcp: true, quiet: true })

    expect(read('.mcp.json')).toBe(once)
    expect(JSON.parse(once)).toEqual({
      mcpServers: { ...own.mcpServers, 'spree-docs': { type: 'http', url: URL } },
      other: true,
    })
  })

  // VS Code allows comments in mcp.json; rewriting it from a failed parse
  // would wipe the developer's own servers.
  it('leaves a config it cannot parse untouched and reports the failure', async () => {
    const commented = '{\n  // my servers\n  "servers": {}\n}\n'
    write('.vscode/mcp.json', commented)

    expect(await addAi(ctx(), { skills: false, mcp: true, quiet: true })).toBe(false)

    expect(read('.vscode/mcp.json')).toBe(commented)
    expect(JSON.parse(read('.mcp.json')).mcpServers['spree-docs']).toBeDefined()
  })

  it('points the agent instructions at the docs server once', async () => {
    write('AGENTS.md', '# My project\n')
    write('CLAUDE.md', '@AGENTS.md\n')

    await addAi(ctx(), { skills: false, mcp: true, quiet: true })
    await addAi(ctx(), { skills: false, mcp: true, quiet: true })

    expect(read('AGENTS.md').match(/## Searching the Spree docs/g)).toHaveLength(1)
    expect(read('AGENTS.md')).toMatch(/^# My project\n\n## Searching the Spree docs/)
    expect(read('CLAUDE.md')).toBe('@AGENTS.md\n')
  })

  it('falls back to CLAUDE.md in projects without AGENTS.md', async () => {
    write('CLAUDE.md', '# Older project\n')

    await addAi(ctx(), { skills: false, mcp: true, quiet: true })

    expect(read('CLAUDE.md')).toContain('`spree-docs` MCP server')
  })

  it('points at the local docs only when the project installs them', async () => {
    write('AGENTS.md', '# Without local docs\n')
    await addAi(ctx(), { skills: false, mcp: true, quiet: true })
    expect(read('AGENTS.md')).not.toContain('node_modules/@spree/docs')

    write('AGENTS.md', '# With local docs\n')
    write('package.json', JSON.stringify({ dependencies: { '@spree/docs': 'latest' } }))
    await addAi(ctx(), { skills: false, mcp: true, quiet: true })
    expect(read('AGENTS.md')).toContain('node_modules/@spree/docs/dist/')
  })

  it("installs the agent skills with the project's package manager", async () => {
    write('pnpm-lock.yaml', '')

    expect(await addAi(ctx(), { skills: true, mcp: false, quiet: true })).toBe(true)

    expect(vi.mocked(execa)).toHaveBeenCalledWith(
      'pnpm',
      ['dlx', 'skills', 'add', 'spree/agent-skills', '--skill', '*', '--yes'],
      expect.objectContaining({ cwd: projectDir }),
    )
    expect(fs.existsSync(path.join(projectDir, '.mcp.json'))).toBe(false)
  })

  it('reports a failed skills install without undoing the docs server', async () => {
    vi.mocked(execa).mockRejectedValueOnce(new Error('network down'))

    expect(await addAi(ctx(), { skills: true, mcp: true, quiet: true })).toBe(false)

    expect(JSON.parse(read('.mcp.json')).mcpServers['spree-docs']).toBeDefined()
  })
})
