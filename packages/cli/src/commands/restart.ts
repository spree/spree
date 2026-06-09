import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerCompose } from '../docker.js'

// `docker compose restart` sends SIGTERM, the container's PID 1 exits, Docker
// re-launches it. Same image, same volumes, fresh Rails process — fast and
// matches the "just restart the app" intent.
//
// Right for: config/initializers/*.rb changes, code that's loaded once at
// boot, any change Zeitwerk doesn't auto-reload.
//
// NOT right for: Gemfile changes (need `spree bundle install` first, then
// `spree stop && spree dev` to recreate the container from the updated
// bundle), Dockerfile / .ruby-version changes (need `spree build`), or
// compose file changes (need recreate). For those, use the heavier path.
export function registerRestartCommand(program: Command): void {
  program
    .command('restart')
    .description('Restart web + worker in place (does not reload Gemfile or compose changes)')
    .action(async () => {
      const ctx = detectProject()

      const s = p.spinner()
      s.start('Restarting web + worker...')
      try {
        await dockerCompose(['restart', 'web', 'worker'], ctx.projectDir)
        s.stop('Services restarted.')
      } catch (error) {
        // Without this, the spinner stays "live" when the top-level
        // handler prints the error — output lands under a stale prompt.
        s.stop('Restart failed.')
        throw error
      }
    })
}
