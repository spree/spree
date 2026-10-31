import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { addAi } from '../src/commands/add.js'
import { run } from '../src/lib/run'
import type { ProjectContext } from '../src/types.js'

vi.mock('../src/lib/run', () => ({ run: vi.fn(async () => ({})) }))

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
    vi.mocked(run).mockClear()
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

  // Claude Code reads CLAUDE.md alone, so one that does not import AGENTS.md
  // needs the section itself.
  it('also updates a CLAUDE.md that does not import AGENTS.md', async () => {
    write('AGENTS.md', '# Shared\n')
    write('CLAUDE.md', '# Claude only\n')

    await addAi(ctx(), { skills: false, mcp: true, quiet: true })

    expect(read('AGENTS.md')).toContain('`spree-docs` MCP server')
    expect(read('CLAUDE.md')).toContain('`spree-docs` MCP server')
  })

  it('installs the skills with npx in Yarn projects, since Yarn 1 has no dlx', async () => {
    write('yarn.lock', '')

    await addAi(ctx(), { skills: true, mcp: false, quiet: true })

    expect(vi.mocked(run)).toHaveBeenCalledWith(
      'npx',
      ['--yes', 'skills', 'add', 'spree/agent-skills', '--skill', '*', '--yes'],
      expect.anything(),
    )
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

  // One file that cannot be written must not stop the rest of the setup, and
  // must be left whole. The failure is injected: file permissions do not
  // stop a test run as root.
  it('still installs the skills when an instructions file cannot be written', async () => {
    write('AGENTS.md', '# Mine\n')
    const rename = fs.renameSync
    const failure = vi.spyOn(fs, 'renameSync').mockImplementation((from, to) => {
      if (String(to).endsWith('AGENTS.md')) throw new Error('disk full')
      rename(from, to)
    })

    try {
      expect(await addAi(ctx(), { skills: true, mcp: true, quiet: true })).toBe(false)
    } finally {
      failure.mockRestore()
    }

    expect(read('AGENTS.md')).toBe('# Mine\n')
    expect(fs.readdirSync(projectDir).filter((file) => file.endsWith('.tmp'))).toEqual([])
    expect(JSON.parse(read('.mcp.json')).mcpServers['spree-docs']).toBeDefined()
    expect(vi.mocked(run)).toHaveBeenCalledWith(
      expect.any(String),
      expect.arrayContaining(['skills', 'add', 'spree/agent-skills']),
      expect.anything(),
    )
  })

  it('keeps the permissions of the files it updates', async () => {
    write('.mcp.json', '{}')
    write('AGENTS.md', '# Private\n')
    fs.chmodSync(path.join(projectDir, '.mcp.json'), 0o600)
    fs.chmodSync(path.join(projectDir, 'AGENTS.md'), 0o640)

    await addAi(ctx(), { skills: false, mcp: true, quiet: true })

    const mode = (file: string) => fs.statSync(path.join(projectDir, file)).mode & 0o777
    expect(read('.mcp.json')).toContain('spree-docs')
    expect(mode('.mcp.json')).toBe(0o600)
    expect(mode('AGENTS.md')).toBe(0o640)
  })

  it('does not replace a read-only instructions file', async () => {
    write('AGENTS.md', '# Read-only\n')
    const access = vi.spyOn(fs, 'accessSync').mockImplementation(() => {
      throw Object.assign(new Error('permission denied'), { code: 'EACCES' })
    })

    try {
      expect(await addAi(ctx(), { skills: false, mcp: true, quiet: true })).toBe(false)
    } finally {
      access.mockRestore()
    }

    expect(read('AGENTS.md')).toBe('# Read-only\n')
  })

  it("installs the agent skills with the project's package manager", async () => {
    write('pnpm-lock.yaml', '')

    expect(await addAi(ctx(), { skills: true, mcp: false, quiet: true })).toBe(true)

    expect(vi.mocked(run)).toHaveBeenCalledWith(
      'pnpm',
      ['dlx', 'skills', 'add', 'spree/agent-skills', '--skill', '*', '--yes'],
      expect.objectContaining({ cwd: projectDir }),
    )
    expect(fs.existsSync(path.join(projectDir, '.mcp.json'))).toBe(false)
  })

  it('reports a failed skills install without undoing the docs server', async () => {
    vi.mocked(run).mockRejectedValueOnce(new Error('network down'))

    expect(await addAi(ctx(), { skills: true, mcp: true, quiet: true })).toBe(false)

    expect(JSON.parse(read('.mcp.json')).mcpServers['spree-docs']).toBeDefined()
  })
})
