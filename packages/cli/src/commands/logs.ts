import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { streamLogs } from '../docker.js'

export function registerLogsCommand(program: Command): void {
  program
    .command('logs')
    .description('Stream service logs')
    .argument('[service]', 'service name (web or worker)', 'web')
    .action(async (service: string) => {
      const ctx = detectProject()
      await streamLogs(service, ctx.projectDir)
    })
}
