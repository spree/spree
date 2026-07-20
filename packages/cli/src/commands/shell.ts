import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExecOrRun } from '../docker.js'

// Open an interactive bash shell in the web container — the system-shell
// sibling of `spree console` (Rails) and `spree db:console` (psql). One-off
// non-interactive commands belong to `spree exec` instead.
//
// When web is down — a crash-looping container is exactly when a shell is
// most useful — fall back to a one-off `compose run` shell against the same
// volumes (its depends_on health-waits postgres).
export function registerShellCommand(program: Command): void {
  program
    .command('shell')
    .alias('bash')
    .description('Open an interactive bash shell inside the web container')
    .action(async () => {
      const ctx = detectProject()
      await dockerComposeExecOrRun(['bash'], ctx.projectDir, {
        edgeHint: 'then open the shell',
      })
    })
}
