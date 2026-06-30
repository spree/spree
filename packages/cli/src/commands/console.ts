import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { detectProject, hasMonorepoSpreePath } from '../context.js'
import { dockerComposeExec, dockerComposeRun, isServiceRunning } from '../docker.js'

export function registerConsoleCommand(program: Command): void {
  program
    .command('console')
    .description('Open Rails console')
    .action(async () => {
      const ctx = detectProject()

      if (await isServiceRunning('web', ctx.projectDir)) {
        await dockerComposeExec(['bin/rails', 'console'], ctx.projectDir)
        return
      }

      // web is down — a crash-looping container is exactly when an inspection
      // console is most useful. A one-off `compose run` boots a fresh, transient
      // console against the same warm DB (its depends_on starts + health-waits
      // postgres), mirroring `spree bundle`'s fallback. But `run` materializes
      // the project-local compose, which is wrong under the monorepo edge overlay
      // — refuse there, like bundle.ts.
      if (hasMonorepoSpreePath(ctx.projectDir)) {
        p.cancel(
          [
            'The web container is not running, and this is a monorepo edge project.',
            `Run ${pc.bold('pnpm server:dev')} from the monorepo root, then open the console.`,
          ].join('\n'),
        )
        process.exit(1)
      }

      p.log.info(
        'web container is not running — using a one-off container (`docker compose run`) instead.',
      )
      await dockerComposeRun(['bin/rails', 'console'], ctx.projectDir)
    })
}
