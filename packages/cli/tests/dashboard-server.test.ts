import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
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

  // Its own process group gets no hang-up when the terminal closes, so the
  // server listens for it and stops; stop() removes those listeners again.
  it('stops on SIGHUP and SIGTERM until stopped', () => {
    const dashboardDir = path.join(projectDir, 'apps', 'dashboard')
    fs.mkdirSync(path.join(dashboardDir, 'node_modules'), { recursive: true })
    fs.writeFileSync(
      path.join(dashboardDir, 'package.json'),
      '{"name":"dashboard","scripts":{"dev":"node -e \\"setTimeout(() => {}, 60000)\\""}}\n',
    )
    const hup = process.listenerCount('SIGHUP')
    const term = process.listenerCount('SIGTERM')

    const server = startDashboardDevServer(projectDir)
    expect(process.listenerCount('SIGHUP')).toBe(hup + 1)
    expect(process.listenerCount('SIGTERM')).toBe(term + 1)

    server?.stop()
    expect(process.listenerCount('SIGHUP')).toBe(hup)
    expect(process.listenerCount('SIGTERM')).toBe(term)
  })

  // A real hang-up or SIGTERM stops the dev server's whole process group and
  // exits with the signal's conventional status.
  it.each([
    ['SIGHUP', 129],
    ['SIGTERM', 143],
  ] as const)(
    '%s stops the dev server and exits with %i',
    async (signal, status) => {
      const dashboardDir = path.join(projectDir, 'apps', 'dashboard')
      const pidFile = path.join(projectDir, 'dev.pid')
      fs.mkdirSync(path.join(dashboardDir, 'node_modules'), { recursive: true })
      const script = `require('fs').writeFileSync(${JSON.stringify(pidFile)}, String(process.pid)); setTimeout(() => {}, 60000)`
      fs.writeFileSync(
        path.join(dashboardDir, 'package.json'),
        JSON.stringify({
          name: 'dashboard',
          scripts: { dev: `node -e ${JSON.stringify(script)}` },
        }),
      )
      const exit = vi.spyOn(process, 'exit').mockImplementation((() => undefined) as never)

      const server = startDashboardDevServer(projectDir)
      await vi.waitFor(() => expect(fs.existsSync(pidFile)).toBe(true), { timeout: 10_000 })
      const pid = Number(fs.readFileSync(pidFile, 'utf8'))

      process.emit(signal, signal)

      expect(exit).toHaveBeenCalledWith(status)
      expect(await server?.url).toBeNull()
      await vi.waitFor(() => expect(() => process.kill(pid, 0)).toThrow(), { timeout: 10_000 })
      exit.mockRestore()
    },
    20_000,
  )
})
