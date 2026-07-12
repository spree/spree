import fs from 'node:fs'
import path from 'node:path'
import { execa } from 'execa'
import { DASHBOARD_REPO } from './constants.js'
import { dashboardEnvContent } from './templates/env.js'
import type { PackageManager } from './types.js'
import { installCommand } from './utils.js'

export async function downloadDashboard(projectDir: string): Promise<void> {
  const dashboardDir = path.join(projectDir, 'apps', 'dashboard')
  await execa('git', ['clone', '--depth', '1', '--', DASHBOARD_REPO, dashboardDir], {
    stdio: 'ignore',
  })
  fs.rmSync(path.join(dashboardDir, '.git'), { recursive: true, force: true })
}

export async function installDashboardDeps(projectDir: string, pm: PackageManager): Promise<void> {
  const dashboardDir = path.join(projectDir, 'apps', 'dashboard')
  const [cmd, ...args] = installCommand(pm).split(' ')
  await execa(cmd, args, { cwd: dashboardDir, stdio: 'ignore' })
}

export function writeDashboardEnv(projectDir: string, port: number): void {
  const envPath = path.join(projectDir, 'apps', 'dashboard', '.env.local')
  fs.writeFileSync(envPath, dashboardEnvContent(port))
}
