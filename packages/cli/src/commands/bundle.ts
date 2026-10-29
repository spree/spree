import type { Command } from 'commander'
import { bundleCommand } from '../backend.js'
import { detectProject } from '../context.js'
import { warnDeprecated } from '../deprecation.js'
import { dockerComposeExecOrRun } from '../docker.js'
import { addCommandFor } from '../lib/extensions.js'

// Deprecated: extensions are installed with `spree add`, anything else goes
// through `spree exec bundle …`.
//
// Gemfile.lock drift crashes the containers before `exec` can reach them —
// exactly the state where bundler is needed most — so when web is down we fall
// back to a one-off `compose run` container, which mounts the same bundle_cache
// volume so gems land where the next boot expects them.
export function registerBundleCommand(program: Command): void {
  program
    .command('bundle', { hidden: true })
    .description('Deprecated: use `spree add <extension>` or `spree exec bundle …`')
    .argument('<args...>', 'arguments to pass to bundle')
    .allowUnknownOption(true)
    .passThroughOptions(true)
    .action(async (args: string[]) => {
      // A bare `bundle add <gem>` maps onto `spree add`; any extra option
      // (a version, a source) only survives through `spree exec`.
      const gem =
        args[0] === 'add' && args.length === 2 && !args[1].startsWith('-') ? args[1] : undefined
      warnDeprecated(
        'spree bundle',
        gem ? addCommandFor(gem) : `spree exec bundle ${args.join(' ')}`,
      )
      const ctx = detectProject()
      await dockerComposeExecOrRun(bundleCommand(args), ctx.projectDir, {
        edgeHint: 'the edge stack heals gem drift on boot',
      })
    })
}
