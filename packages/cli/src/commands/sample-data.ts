import type { Command } from 'commander'
import * as p from '@clack/prompts'
import { detectProject } from '../context.js'
import { dockerCompose } from '../docker.js'

export function registerSampleDataCommand(program: Command): void {
  program
    .command('sample-data')
    .description('Load sample data (products, categories, images)')
    .action(async () => {
      const ctx = detectProject()

      const s = p.spinner()
      s.start('Loading sample data...')
      await dockerCompose(
        ['exec', '-T', 'web', 'bin/rails', 'spree:load_sample_data'],
        ctx.projectDir,
      )
      s.stop('Sample data loaded.')
    })
}
