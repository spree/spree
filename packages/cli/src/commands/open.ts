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
      // The React dashboard runs on its own Vite server (`spree dev`). Without
      // one, open the store: /dashboard serves a production build and isn't a
      // development target.
      const url = hasDashboardApp(ctx.projectDir)
        ? `http://localhost:${DASHBOARD_PORT}`
        : `http://localhost:${ctx.port}`
      const os = platform()
      const cmd = os === 'darwin' ? 'open' : os === 'win32' ? 'start' : 'xdg-open'
      await execaCommand(`${cmd} ${url}`)
    })
}
