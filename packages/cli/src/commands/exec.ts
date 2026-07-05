import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExec } from '../docker.js'

// Universal escape hatch: run an arbitrary command inside the web container.
// Anything not pre-wrapped by another `spree` command can be reached via this.
//   spree exec ls -la
//   spree exec bash
//   spree exec env | sort
export function registerExecCommand(program: Command): void {
  program
    .command('exec')
    .description('Run an arbitrary command inside the web container')
    .argument('<command...>', 'command and arguments to run')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (command: string[]) => {
      const ctx = detectProject()
      await dockerComposeExec(command, ctx.projectDir)
    })
}
