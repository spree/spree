import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('execa', () => ({ execa: vi.fn().mockResolvedValue({ stdout: '27.3.1' }) }))

import { clientRows } from '../src/commands/info'

let projectDir: string

beforeEach(() => {
  projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-info-'))
  fs.writeFileSync(
    path.join(projectDir, 'package.json'),
    JSON.stringify({ devDependencies: { '@spree/cli': '6.0.4', 'left-pad': '1.0.0' } }),
  )
  fs.writeFileSync(path.join(projectDir, 'pnpm-lock.yaml'), '')
  fs.mkdirSync(path.join(projectDir, 'node_modules', '@spree', 'cli'), { recursive: true })
  fs.writeFileSync(
    path.join(projectDir, 'node_modules', '@spree', 'cli', 'package.json'),
    JSON.stringify({ version: '6.0.4' }),
  )
})

afterEach(() => fs.rmSync(projectDir, { recursive: true, force: true }))

describe('clientRows', () => {
  it('reports the tooling and installed @spree packages only', async () => {
    const rows = await clientRows(projectDir)

    expect(rows).toMatchObject({
      Node: process.version,
      'Package manager': 'pnpm',
      Docker: '27.3.1',
    })
    expect(rows['@spree/cli']).toBeDefined()
    expect(Object.keys(rows)).not.toContain('left-pad')
  })
})
