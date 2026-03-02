import type { Command } from 'commander'
import * as p from '@clack/prompts'
import { detectProject } from '../context.js'
import { dockerCompose } from '../docker.js'

export function registerUpdateCommand(program: Command): void {
  program
    .command('update')
    .description('Pull latest image and recreate containers')
    .action(async () => {
      const ctx = detectProject()

      const s = p.spinner()

      s.start('Pulling latest images...')
      await dockerCompose(['pull'], ctx.projectDir)
      s.stop('Images pulled.')

      s.start('Recreating containers...')
      await dockerCompose(['up', '-d'], ctx.projectDir)
      s.stop('Containers recreated.')

      p.log.success('Update complete! Migrations will run automatically on startup.')
      p.log.info('Run `spree logs` to follow the startup progress.')
    })
}
