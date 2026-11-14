import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { spreeTask } from '../backend.js'
import { detectProject } from '../context.js'
import { captureTask } from '../docker.js'

export function registerSampleDataCommand(program: Command): void {
  program
    .command('sample-data')
    .description('Load sample data (products, categories, images)')
    .action(async () => {
      const ctx = detectProject()

      const s = p.spinner()
      s.start('Loading sample data...')
      await captureTask(spreeTask('load_sample_data'), ctx.projectDir)
      s.stop('Sample data loaded.')
    })
}
