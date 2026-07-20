import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { planProductionBuild } from '../src/commands/build.js'

/**
 * Pure planning logic for `spree build --production` — the safety contract:
 * a layout-normalizing Dockerfile builds from the project root (the ejected
 * backend and apps/dashboard travel in the context, zero flags); an older
 * Dockerfile keeps the backend/ context it expects, with the dashboard
 * flagged as left out.
 */
describe('planProductionBuild', () => {
  let projectDir: string

  beforeEach(() => {
    projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-prod-build-'))
    fs.mkdirSync(path.join(projectDir, 'backend'))
  })

  afterEach(() => {
    fs.rmSync(projectDir, { recursive: true, force: true })
  })

  // The marker the layout-normalizing starter Dockerfile carries.
  const NORMALIZING_DOCKERFILE = 'FROM alpine AS ctx\n# .spree-custom-dashboard\nFROM ruby\n'

  function writeDockerfile(content: string) {
    fs.writeFileSync(path.join(projectDir, 'backend', 'Dockerfile'), content)
  }

  function writeDashboardApp() {
    const dir = path.join(projectDir, 'apps', 'dashboard')
    fs.mkdirSync(path.join(dir, 'src'), { recursive: true })
    fs.writeFileSync(path.join(dir, 'package.json'), '{"name":"dashboard"}\n')
  }

  it('throws without a backend Dockerfile', () => {
    expect(() => planProductionBuild(projectDir)).toThrow(/backend\/Dockerfile/)
  })

  it('builds from the project root with a layout-normalizing Dockerfile', () => {
    writeDockerfile(NORMALIZING_DOCKERFILE)
    writeDashboardApp()

    const plan = planProductionBuild(projectDir, 'shop:1')

    expect(plan.dashboard).toBe('custom')
    expect(plan.args).toEqual([
      'build',
      projectDir,
      '-f',
      path.join(projectDir, 'backend', 'Dockerfile'),
      '-t',
      'shop:1',
    ])
  })

  it('writes the root .dockerignore when missing, never overwriting', () => {
    writeDockerfile(NORMALIZING_DOCKERFILE)

    planProductionBuild(projectDir)
    const ignorePath = path.join(projectDir, '.dockerignore')
    expect(fs.readFileSync(ignorePath, 'utf-8')).toContain('**/node_modules')

    fs.writeFileSync(ignorePath, '# mine\n')
    planProductionBuild(projectDir)
    expect(fs.readFileSync(ignorePath, 'utf-8')).toBe('# mine\n')
  })

  it('reports stock for a normalizing Dockerfile without a dashboard app', () => {
    writeDockerfile(NORMALIZING_DOCKERFILE)

    const plan = planProductionBuild(projectDir)

    expect(plan.dashboard).toBe('stock-or-none')
    expect(plan.args[1]).toBe(projectDir)
  })

  it('keeps the backend/ context for a pre-normalization Dockerfile', () => {
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
    // No root-context machinery for a Dockerfile that can't use it.
    expect(fs.existsSync(path.join(projectDir, '.dockerignore'))).toBe(false)
  })

  it('flags a pre-normalization Dockerfile when a dashboard would be left out', () => {
    writeDockerfile('FROM ruby\n')
    writeDashboardApp()

    const plan = planProductionBuild(projectDir)

    expect(plan.dashboard).toBe('unsupported-dockerfile')
    expect(plan.args[1]).toBe(path.join(projectDir, 'backend'))
  })

  it('derives a sanitized default tag from the project directory', () => {
    writeDockerfile(NORMALIZING_DOCKERFILE)

    const plan = planProductionBuild(projectDir)

    expect(plan.imageTag).toMatch(/^[a-z0-9_-]+-spree:latest$/)
  })
})
