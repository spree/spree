import type { Command } from 'commander'
import { execaCommand } from 'execa'
import { platform } from 'node:os'
import { detectProject } from '../context.js'

export function registerOpenCommand(program: Command): void {
  program
    .command('open')
    .description('Open the admin dashboard in the browser')
    .action(async () => {
      const ctx = detectProject()
      const url = `http://localhost:${ctx.port}/admin`
      const os = platform()
      const cmd = os === 'darwin' ? 'open' : os === 'win32' ? 'start' : 'xdg-open'
      await execaCommand(`${cmd} ${url}`)
    })
}
