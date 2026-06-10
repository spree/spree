import type { Command } from 'commander'
import { detectProject } from '../context.js'
import { dockerComposeExec } from '../docker.js'

// Run bundler inside the web container. Gems install into the bundle_cache
// volume and persist across container restarts without an image rebuild.
//   spree bundle add stripe
//   spree bundle update spree spree_api
//   spree bundle outdated
export function registerBundleCommand(program: Command): void {
  program
    .command('bundle')
    .description('Run a bundler command (`bundle …`) inside the web container')
    .argument('<args...>', 'arguments to pass to bundle')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (args: string[]) => {
      const ctx = detectProject()
      await dockerComposeExec(['bundle', ...args], ctx.projectDir)
    })
}
