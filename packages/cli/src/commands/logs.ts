import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { detectProject } from '../context.js'
import { appServices, streamLogs } from '../docker.js'

export function registerLogsCommand(program: Command): void {
  program
    .command('logs')
    .description('Stream service logs')
    .argument('[service]', 'service name (e.g. web)', 'web')
    .action(async (service: string) => {
      const ctx = detectProject()
      // Solid Queue projects have no worker service — jobs run inside the web
      // process, so their logs are web's logs.
      if (service === 'worker' && !(await appServices(ctx.projectDir)).includes('worker')) {
        p.log.info(
          `This project has no ${pc.bold('worker')} service — jobs run inside the web process ` +
            `(Solid Queue in Puma). Streaming ${pc.bold('web')} logs; the job dashboard is at ` +
            `${pc.cyan(`http://localhost:${ctx.port}/jobs`)}.`,
        )
        await streamLogs('web', ctx.projectDir)
        return
      }
      await streamLogs(service, ctx.projectDir)
    })
}
