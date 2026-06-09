import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_PASSWORD } from '../constants.js'
import { detectProject } from '../context.js'
import { dockerCompose, streamLogs } from '../docker.js'

export function registerDevCommand(program: Command): void {
  program
    .command('dev')
    .description('Start services and stream logs')
    .action(async () => {
      const ctx = detectProject()

      if (hasMonorepoSpreePath(ctx.projectDir)) {
        p.cancel(
          [
            'This project uses SPREE_PATH for monorepo development.',
            `Use ${pc.bold('pnpm server:start')} from the monorepo root instead of ${pc.bold('spree dev')}.`,
            'It loads the edge compose overlay and sets SPREE_PATH so the Spree gems resolve to the monorepo source.',
          ].join('\n'),
        )
        process.exit(1)
      }

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

function hasMonorepoSpreePath(projectDir: string): boolean {
  const envPath = path.join(projectDir, '.env')
  if (!fs.existsSync(envPath)) return false
  try {
    const contents = fs.readFileSync(envPath, 'utf-8')
    return /^\s*SPREE_PATH\s*=/m.test(contents)
  } catch {
    return false
  }
}
