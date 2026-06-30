import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { detectProject, hasMonorepoSpreePath } from '../context.js'
import { dockerComposeExec, dockerComposeRun, isServiceRunning } from '../docker.js'

// Run bundler inside the web container. Gems install into the bundle_cache
// volume and persist across container restarts without an image rebuild.
//   spree bundle add stripe
//   spree bundle update spree spree_api
//   spree bundle outdated
export function registerBundleCommand(program: Command): void {
  program
    .command('bundle')
    .description('Run a bundler command (`bundle …`) inside the web container')
    .argument('<args...>', 'arguments to pass to bundle')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (args: string[]) => {
      const ctx = detectProject()

      if (await isServiceRunning('web', ctx.projectDir)) {
        await dockerComposeExec(['bundle', ...args], ctx.projectDir)
        return
      }

      // Gemfile.lock drift crashes the containers before `exec` can reach
      // them — exactly the state where bundler is needed most. A one-off
      // `compose run` container mounts the same bundle_cache volume, so
      // gems land where the next boot expects them.
      if (hasMonorepoSpreePath(ctx.projectDir)) {
        p.cancel(
          [
            'The web container is not running, and this is a monorepo edge project.',
            `Run ${pc.bold('pnpm server:dev')} from the monorepo root — the edge stack heals gem drift on boot.`,
          ].join('\n'),
        )
        process.exit(1)
      }

      p.log.info(
        'web container is not running — using a one-off container (`docker compose run`) instead.',
      )
      await dockerComposeRun(['bundle', ...args], ctx.projectDir)
    })
}
