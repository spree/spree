import { Command } from 'commander'
import pc from 'picocolors'
import { registerAddCommand } from './commands/add.js'
import { registerApiCommand } from './commands/api.js'
import { registerApiKeyCommand } from './commands/api-key.js'
import { registerAuthCommand } from './commands/auth.js'
import { registerBuildCommand } from './commands/build.js'
import { registerBundleCommand } from './commands/bundle.js'
import { registerCompletionCommand } from './commands/completion.js'
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
import { registerPluginCommand } from './commands/plugin.js'
import { registerRailsCommand } from './commands/rails.js'
import { registerRakeCommand } from './commands/rake.js'
import { registerRestartCommand } from './commands/restart.js'
import { registerRoutesCommand } from './commands/routes.js'
import { registerRspecCommand } from './commands/rspec.js'
import { registerSampleDataCommand } from './commands/sample-data.js'
import { registerSeedCommand } from './commands/seed.js'
import { registerShellCommand } from './commands/shell.js'
import { registerStopCommand } from './commands/stop.js'
import { registerTaskCommand } from './commands/task.js'
import { registerUpdateCommand } from './commands/update.js'
import { registerUpgradeCommand } from './commands/upgrade.js'
import { registerUserCommand } from './commands/user.js'
import { VERSION } from './version.js'

const program = new Command()
  .name('spree')
  .description('CLI for managing Spree Commerce projects')
  .version(VERSION)
  // Required by passThroughOptions on subcommands (exec/rails/bundle/rake/task/rspec)
  // so flags like `ls -la` or `bin/rails routes -g foo` reach the inner command
  // instead of being parsed as options of the spree subcommand.
  .enablePositionalOptions()
  // "did you mean …" on an unknown command/option (on by default; explicit so
  // it isn't lost in a future refactor) + a nudge toward help on error.
  .showSuggestionAfterError(true)
  .showHelpAfterError('(run `spree --help` for usage)')
  // Must be set BEFORE registering subcommands — commander copies the exit
  // callback to each subcommand at `.command()` creation time, so a later call
  // would leave subcommands (e.g. `api endpoints --format`) on the default
  // handler. Commander invokes this then calls process.exit with the error's
  // code, so we exit directly: 0 for help/version, 2 for usage errors,
  // matching the rest of the `spree api` surface. The message is already printed.
  .exitOverride((err) => {
    // Help (`spree api` with no subcommand, `--help`) and `--version` are
    // successful exits, not errors. Everything else reaching here is a usage
    // error → 2.
    if (err.code.startsWith('commander.help') || err.code === 'commander.version') {
      process.exit(0)
    }
    process.exit(2)
  })

// Lifecycle / setup
registerInitCommand(program)
registerAddCommand(program)
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
registerRspecCommand(program)
registerConsoleCommand(program)
registerShellCommand(program)

// Spree-specific helpers
registerUserCommand(program)
registerApiKeyCommand(program)
registerOpenCommand(program)
registerSeedCommand(program)
registerSampleDataCommand(program)
registerPluginCommand(program)

// Admin API access (works against any Spree 5.5+ instance, not just local projects)
registerApiCommand(program)
registerAuthCommand(program)
registerCompletionCommand(program)

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

    if (err instanceof Error && 'code' in err && String(err.code).startsWith('commander.')) {
      process.exit(2)
    }

    // CredentialError carries no special code; it's a configuration problem (2).
    const exitCode = err instanceof Error && err.constructor.name === 'CredentialError' ? 2 : 1
    const message = err instanceof Error ? err.message : 'An unexpected error occurred.'
    console.error(`\n${pc.red('Error:')} ${message}\n`)
    process.exit(exitCode)
  }
}

main()
