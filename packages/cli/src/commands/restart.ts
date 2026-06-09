import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerCompose } from '../docker.js'

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
        s.stop('Restart failed.')
        throw error
      }
    })
}
