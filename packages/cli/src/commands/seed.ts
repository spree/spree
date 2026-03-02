import type { Command } from 'commander'
import * as p from '@clack/prompts'
import { detectProject } from '../context.js'
import { rakeTask } from '../docker.js'

export function registerSeedCommand(program: Command): void {
  program
    .command('seed')
    .description('Seed the database')
    .action(async () => {
      const ctx = detectProject()

      const s = p.spinner()
      s.start('Seeding database...')
      await rakeTask('db:seed', ctx.projectDir)
      s.stop('Database seeded.')
    })
}
