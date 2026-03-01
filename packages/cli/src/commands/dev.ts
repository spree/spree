import type { Command } from 'commander'
import * as p from '@clack/prompts'
import pc from 'picocolors'
import { detectProject } from '../context.js'
import { dockerCompose, streamLogs } from '../docker.js'
import { DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_PASSWORD } from '../constants.js'

export function registerDevCommand(program: Command): void {
  program
    .command('dev')
    .description('Start services and stream logs')
    .action(async () => {
      const ctx = detectProject()

      const s = p.spinner()
      s.start('Starting Docker services...')
      await dockerCompose(['up', '-d'], ctx.projectDir)
      s.stop('Docker services started.')

      p.note(
        [
          '',
          pc.bold('Admin Dashboard'),
          `  ${pc.cyan(`http://localhost:${ctx.port}/admin`)}`,
          `  Email:    ${DEFAULT_ADMIN_EMAIL}`,
          `  Password: ${DEFAULT_ADMIN_PASSWORD}`,
          '',
          pc.bold('Store API'),
          `  ${pc.cyan(`http://localhost:${ctx.port}/api/v3/store`)}`,
          '',
        ].join('\n'),
        'Spree Commerce',
      )

      p.log.info('Streaming logs (Ctrl+C to stop)...\n')
      await streamLogs('web', ctx.projectDir)
    })
}
