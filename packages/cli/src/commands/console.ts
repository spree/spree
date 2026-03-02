import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { railsConsole } from '../docker.js'

export function registerConsoleCommand(program: Command): void {
  program
    .command('console')
    .description('Open Rails console')
    .action(async () => {
      const ctx = detectProject()
      await railsConsole(ctx.projectDir)
    })
}
