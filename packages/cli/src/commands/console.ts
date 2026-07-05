import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExecOrRun } from '../docker.js'

export function registerConsoleCommand(program: Command): void {
  program
    .command('console')
    .description('Open Rails console')
    .action(async () => {
      const ctx = detectProject()
      // When web is down — a crash-looping container is exactly when an
      // inspection console is most useful — fall back to a one-off `compose run`
      // console against the same warm DB (its depends_on health-waits postgres).
      await dockerComposeExecOrRun(['bin/rails', 'console'], ctx.projectDir, {
        edgeHint: 'then open the console',
      })
    })
}
