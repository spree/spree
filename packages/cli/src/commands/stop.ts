import type { Command } from 'commander'
import * as p from '@clack/prompts'
import { detectProject } from '../context.js'
import { dockerCompose } from '../docker.js'

export function registerStopCommand(program: Command): void {
  program
    .command('stop')
    .description('Stop services')
    .action(async () => {
      const ctx = detectProject()

      const s = p.spinner()
      s.start('Stopping services...')
      await dockerCompose(['stop'], ctx.projectDir)
      s.stop('Services stopped.')
    })
}
