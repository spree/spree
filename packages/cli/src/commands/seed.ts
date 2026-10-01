import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { SEED_TASK } from '../backend.js'
import { detectProject } from '../context.js'
import { captureTask } from '../docker.js'

export function registerSeedCommand(program: Command): void {
  program
    .command('seed')
    .description('Seed the database')
    .action(async () => {
      const ctx = detectProject()

      const s = p.spinner()
      s.start('Seeding database...')
      await captureTask(SEED_TASK, ctx.projectDir)
      s.stop('Database seeded.')
    })
}
