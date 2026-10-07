import { platform } from 'node:os'
import type { Command } from 'commander'
import { execaCommand } from 'execa'
import { DASHBOARD_PORT } from '../constants.js'
import { detectProject } from '../context.js'
import { hasDashboardApp } from '../dashboard-server.js'

export function registerOpenCommand(program: Command): void {
  program
    .command('open')
    .description('Open the admin dashboard in the browser')
    .action(async () => {
      const ctx = detectProject()
      // A project's own dashboard runs on its Vite server (`spree dev`);
      // without one, the API serves the built-in dashboard.
      const url = hasDashboardApp(ctx.projectDir)
        ? `http://localhost:${DASHBOARD_PORT}`
        : `http://localhost:${ctx.port}/dashboard`
      const os = platform()
      const cmd = os === 'darwin' ? 'open' : os === 'win32' ? 'start' : 'xdg-open'
      await execaCommand(`${cmd} ${url}`)
    })
}
