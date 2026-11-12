import type { Command } from 'commander'
import { TEST_ENV, testCommand } from '../backend.js'
import { detectProject } from '../context.js'
import { warnDeprecated } from '../deprecation.js'
import { dockerComposeExecOrRun } from '../docker.js'

// Run the backend test suite inside the web container. Anything after `test`
// is forwarded verbatim — file paths, line numbers and flags all work.
//   spree test
//   spree test spec/models/spree/brand_spec.rb:15
//
// The test environment is forced at the exec level: the dev image bakes the
// development environment, and forcing it here keeps every child process
// consistent and keeps tests off the development database.
//
// When web is down we fall back to a one-off `compose run`, whose depends_on
// health-waits postgres — so tests run from a fully cold stack too.
export function registerTestCommand(program: Command): void {
  const run = async (args: string[]) => {
    const ctx = detectProject()
    await dockerComposeExecOrRun(testCommand(args), ctx.projectDir, {
      env: TEST_ENV,
      edgeHint: 'then re-run spree test',
    })
  }

  program
    .command('test')
    .description('Run the backend test suite inside the web container')
    .argument('[args...]', 'files, line numbers and flags to pass to the test runner')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(run)

  program
    .command('rspec', { hidden: true })
    .description('Deprecated: use `spree test`')
    .argument('[args...]')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (args: string[]) => {
      warnDeprecated('spree rspec', 'spree test')
      await run(args)
    })
}
