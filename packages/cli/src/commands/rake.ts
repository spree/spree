import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { warnDeprecated } from '../deprecation.js'
import { dockerComposeExecOrRun } from '../docker.js'

// Deprecated: Spree tasks belong to `spree task`, everything else to `spree exec`.
export function registerRakeCommand(program: Command): void {
  program
    .command('rake', { hidden: true })
    .description('Deprecated: use `spree task …` or `spree exec bin/rake …`')
    .argument('<args...>', 'task name and arguments')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (args: string[]) => {
      const [task, ...rest] = args
      warnDeprecated(
        'spree rake',
        task.startsWith('spree:')
          ? `spree task ${[task.slice('spree:'.length), ...rest].join(' ')}`
          : `spree exec bin/rake ${args.join(' ')}`,
      )
      const ctx = detectProject()
      await dockerComposeExecOrRun(['bin/rake', ...args], ctx.projectDir)
    })
}
