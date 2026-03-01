import { Command } from 'commander'
import pc from 'picocolors'
import { registerDevCommand } from './commands/dev.js'
import { registerStopCommand } from './commands/stop.js'
import { registerUpdateCommand } from './commands/update.js'
import { registerLogsCommand } from './commands/logs.js'
import { registerConsoleCommand } from './commands/console.js'
import { registerUserCommand } from './commands/user.js'
import { registerApiKeyCommand } from './commands/api-key.js'
import { registerSeedCommand } from './commands/seed.js'
import { registerSampleDataCommand } from './commands/sample-data.js'

const program = new Command()
  .name('spree')
  .description('CLI for managing Spree Commerce projects')
  .version('0.1.0')

registerDevCommand(program)
registerStopCommand(program)
registerUpdateCommand(program)
registerLogsCommand(program)
registerConsoleCommand(program)
registerUserCommand(program)
registerApiKeyCommand(program)
registerSeedCommand(program)
registerSampleDataCommand(program)

program.exitOverride()

async function main() {
  try {
    await program.parseAsync()
  } catch (err) {
    if (
      err instanceof Error &&
      'code' in err &&
      (err.code === 'commander.helpDisplayed' || err.code === 'commander.version')
    ) {
      process.exit(0)
    }

    const message = err instanceof Error ? err.message : 'An unexpected error occurred.'
    console.error(`\n${pc.red('Error:')} ${message}\n`)
    process.exit(1)
  }
}

main()
