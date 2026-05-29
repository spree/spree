import { Command } from 'commander'
import pc from 'picocolors'
import { registerApiKeyCommand } from './commands/api-key.js'
import { registerConsoleCommand } from './commands/console.js'
import { registerDevCommand } from './commands/dev.js'
import { registerEjectCommand } from './commands/eject.js'
import { registerInitCommand } from './commands/init.js'
import { registerLogsCommand } from './commands/logs.js'
import { registerOpenCommand } from './commands/open.js'
import { registerPluginCommand } from './commands/plugin.js'
import { registerSampleDataCommand } from './commands/sample-data.js'
import { registerSeedCommand } from './commands/seed.js'
import { registerStopCommand } from './commands/stop.js'
import { registerUpdateCommand } from './commands/update.js'
import { registerUserCommand } from './commands/user.js'

const program = new Command()
  .name('spree')
  .description('CLI for managing Spree Commerce projects')
  .version('2.0.0-beta.6')

registerInitCommand(program)
registerDevCommand(program)
registerStopCommand(program)
registerUpdateCommand(program)
registerLogsCommand(program)
registerConsoleCommand(program)
registerUserCommand(program)
registerApiKeyCommand(program)
registerOpenCommand(program)
registerSeedCommand(program)
registerSampleDataCommand(program)
registerEjectCommand(program)
registerPluginCommand(program)

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
