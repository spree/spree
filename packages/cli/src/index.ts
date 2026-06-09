import { Command } from 'commander'
import pc from 'picocolors'
import { registerApiKeyCommand } from './commands/api-key.js'
import { registerBuildCommand } from './commands/build.js'
import { registerBundleCommand } from './commands/bundle.js'
import { registerConsoleCommand } from './commands/console.js'
import { registerDbCommand } from './commands/db.js'
import { registerDevCommand } from './commands/dev.js'
import { registerEjectCommand } from './commands/eject.js'
import { registerExecCommand } from './commands/exec.js'
import { registerGenerateCommand } from './commands/generate.js'
import { registerInitCommand } from './commands/init.js'
import { registerLogsCommand } from './commands/logs.js'
import { registerMigrateCommand } from './commands/migrate.js'
import { registerOpenCommand } from './commands/open.js'
import { registerRailsCommand } from './commands/rails.js'
import { registerRakeCommand } from './commands/rake.js'
import { registerRestartCommand } from './commands/restart.js'
import { registerRoutesCommand } from './commands/routes.js'
import { registerSampleDataCommand } from './commands/sample-data.js'
import { registerSeedCommand } from './commands/seed.js'
import { registerStopCommand } from './commands/stop.js'
import { registerTaskCommand } from './commands/task.js'
import { registerUpdateCommand } from './commands/update.js'
import { registerUpgradeCommand } from './commands/upgrade.js'
import { registerUserCommand } from './commands/user.js'

const program = new Command()
  .name('spree')
  .description('CLI for managing Spree Commerce projects')
  .version('2.0.0')
  // Required by passThroughOptions on subcommands (exec/rails/bundle/rake/task)
  // so flags like `ls -la` or `bin/rails routes -g foo` reach the inner command
  // instead of being parsed as options of the spree subcommand.
  .enablePositionalOptions()

// Lifecycle / setup
registerInitCommand(program)
registerDevCommand(program)
registerStopCommand(program)
registerRestartCommand(program)
registerUpdateCommand(program)
registerLogsCommand(program)
registerEjectCommand(program)
registerBuildCommand(program)

// Dev workflow
registerGenerateCommand(program)
registerMigrateCommand(program)
registerDbCommand(program)
registerRoutesCommand(program)
registerUpgradeCommand(program)

// Run things inside the container
registerExecCommand(program)
registerRailsCommand(program)
registerBundleCommand(program)
registerRakeCommand(program)
registerTaskCommand(program)
registerConsoleCommand(program)

// Spree-specific helpers
registerUserCommand(program)
registerApiKeyCommand(program)
registerOpenCommand(program)
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
