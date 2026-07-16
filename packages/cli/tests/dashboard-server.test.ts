import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { hasDashboardApp, startDashboardDevServer } from '../src/dashboard-server.js'

// The classic (no-dashboard) flow must be a strict no-op: no spawn, no
// output beyond a hint, nothing returned that dev/init would manage.
describe('dashboard-server gating', () => {
  let projectDir: string

  beforeEach(() => {
    projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spree-dash-server-'))
  })

  afterEach(() => {
    fs.rmSync(projectDir, { recursive: true, force: true })
  })

  it('hasDashboardApp is false without apps/dashboard', () => {
    expect(hasDashboardApp(projectDir)).toBe(false)
  })

  it('startDashboardDevServer returns null without apps/dashboard', () => {
    expect(startDashboardDevServer(projectDir)).toBeNull()
  })

  it('returns null (skip, not crash) when dependencies are not installed', () => {
    const dashboardDir = path.join(projectDir, 'apps', 'dashboard')
    fs.mkdirSync(dashboardDir, { recursive: true })
    fs.writeFileSync(path.join(dashboardDir, 'package.json'), '{"name":"dashboard"}\n')
    expect(startDashboardDevServer(projectDir)).toBeNull()
  })

  it('hasDashboardApp is true with a dashboard app', () => {
    const dashboardDir = path.join(projectDir, 'apps', 'dashboard')
    fs.mkdirSync(dashboardDir, { recursive: true })
    fs.writeFileSync(path.join(dashboardDir, 'package.json'), '{"name":"dashboard"}\n')
    expect(hasDashboardApp(projectDir)).toBe(true)
  })
})
