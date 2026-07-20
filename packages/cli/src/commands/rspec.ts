import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExecOrRun } from '../docker.js'

// Run the RSpec suite inside the web container. Anything after `rspec` is
// forwarded verbatim — file paths, line numbers, and rspec flags all work.
//   spree rspec
//   spree rspec spec/models/spree/brand_spec.rb
//   spree rspec spec/models/spree/brand_spec.rb:15
//   spree rspec --format documentation
//
// RAILS_ENV=test is forced at the exec level: the dev image bakes
// RAILS_ENV=development, and while the starter's rails_helper re-forces test
// itself, setting it here keeps the command correct for apps whose helpers
// don't — and keeps every child process (spring, parallel workers) consistent.
// database.yml resolves the spree_test database from RAILS_ENV, so tests never
// touch the development data.
//
// When web is down we fall back to a one-off `compose run`, whose depends_on
// health-waits postgres — so tests run from a fully cold stack too.
export function registerRspecCommand(program: Command): void {
  program
    .command('rspec')
    .description('Run RSpec tests (`bundle exec rspec …`) inside the web container')
    .argument('[args...]', 'files, line numbers, and flags to pass to rspec')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (args: string[]) => {
      const ctx = detectProject()
      await dockerComposeExecOrRun(['bundle', 'exec', 'rspec', ...args], ctx.projectDir, {
        env: { RAILS_ENV: 'test' },
        edgeHint: 'then re-run spree rspec',
      })
    })
}
