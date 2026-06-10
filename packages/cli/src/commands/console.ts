import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExec } from '../docker.js'

export function registerConsoleCommand(program: Command): void {
  program
    .command('console')
    .description('Open Rails console')
    .action(async () => {
      const ctx = detectProject()
      await dockerComposeExec(['bin/rails', 'console'], ctx.projectDir)
    })
}
