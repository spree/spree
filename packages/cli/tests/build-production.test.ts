import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { planProductionBuild } from '../src/commands/build.js'

/**
 * Pure planning logic for `spree build --production` — the safety contract:
 * projects without apps/dashboard (or with a pre-dashboard Dockerfile) build
 * exactly what `docker build backend/` would.
 */
describe('planProductionBuild', () => {
  let projectDir: string
  const staged: string[] = []

  beforeEach(() => {
    projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-prod-build-'))
    fs.mkdirSync(path.join(projectDir, 'backend'))
  })

  afterEach(() => {
    fs.rmSync(projectDir, { recursive: true, force: true })
    for (const dir of staged.splice(0)) fs.rmSync(dir, { recursive: true, force: true })
  })

  function writeDockerfile(content: string) {
    fs.writeFileSync(path.join(projectDir, 'backend', 'Dockerfile'), content)
  }

  function writeDashboardApp() {
    const dir = path.join(projectDir, 'apps', 'dashboard')
    fs.mkdirSync(path.join(dir, 'src'), { recursive: true })
    fs.writeFileSync(path.join(dir, 'package.json'), '{"name":"dashboard"}\n')
    fs.writeFileSync(path.join(dir, 'src', 'main.tsx'), '// entry\n')
    fs.mkdirSync(path.join(dir, 'node_modules', 'left-over'), { recursive: true })
    fs.mkdirSync(path.join(dir, 'dist'))
    fs.writeFileSync(path.join(dir, 'dist', 'stale.js'), '')
  }

  it('throws without a backend Dockerfile', () => {
    expect(() => planProductionBuild(projectDir)).toThrow(/backend\/Dockerfile/)
  })

  it('builds plain when the project has no dashboard app', () => {
    writeDockerfile('FROM ruby\n')

    const plan = planProductionBuild(projectDir, 'shop:1')

    expect(plan.dashboard).toBe('stock-or-none')
    expect(plan.args).toEqual([
      'build',
      path.join(projectDir, 'backend'),
      '-f',
      path.join(projectDir, 'backend', 'Dockerfile'),
      '-t',
      'shop:1',
    ])
    expect(plan.stagedDashboardDir).toBeUndefined()
  })

  it('builds plain and flags a Dockerfile without dashboard support', () => {
    writeDockerfile('FROM ruby\n')
    writeDashboardApp()

    const plan = planProductionBuild(projectDir)

    expect(plan.dashboard).toBe('unsupported-dockerfile')
    expect(plan.args).not.toContain('--build-context')
    expect(plan.args).not.toContain('--build-arg')
  })

  it('selects the custom stage and stages a filtered dashboard copy', () => {
    writeDockerfile('ARG DASHBOARD_SOURCE=stock\nFROM ruby\n')
    writeDashboardApp()

    const plan = planProductionBuild(projectDir)
    if (plan.stagedDashboardDir) staged.push(plan.stagedDashboardDir)

    expect(plan.dashboard).toBe('custom')
    expect(plan.args).toContain('DASHBOARD_SOURCE=custom')
    const contextArg = plan.args[plan.args.indexOf('--build-context') + 1]
    expect(contextArg).toBe(`dashboard-src=${plan.stagedDashboardDir}`)

    // Staged copy carries source but never host artifacts.
    const stagedDir = plan.stagedDashboardDir as string
    expect(fs.existsSync(path.join(stagedDir, 'package.json'))).toBe(true)
    expect(fs.existsSync(path.join(stagedDir, 'src', 'main.tsx'))).toBe(true)
    expect(fs.existsSync(path.join(stagedDir, 'node_modules'))).toBe(false)
    expect(fs.existsSync(path.join(stagedDir, 'dist'))).toBe(false)
  })

  it('derives a sanitized default tag from the project directory', () => {
    writeDockerfile('FROM ruby\n')

    const plan = planProductionBuild(projectDir)

    expect(plan.imageTag).toMatch(/^[a-z0-9_-]+-spree:latest$/)
  })
})
