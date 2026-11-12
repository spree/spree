import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { bundleCommand } from '../backend.js'
import { detectProject, findApiDir, runsFromSource } from '../context.js'
import { warnDeprecated } from '../deprecation.js'
import { dockerComposeExecOrRun } from '../docker.js'
import { addCommandFor, resolveExtension } from '../lib/extensions.js'
import { addUncataloguedExtension } from './add.js'
import { addExtension } from './add-extension.js'

// Subcommands that change the bundle, which the prebuilt image never reads.
const BUNDLE_WRITES = new Set(['add', 'remove', 'install', 'update', 'lock'])

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
      // A bare `bundle add <gem>` is `spree add`; any extra option (a
      // version, a source) only survives through `spree exec`.
      const gem =
        args[0] === 'add' && args.length === 2 && !args[1].startsWith('-') ? args[1] : undefined
      const replacement = gem ? addCommandFor(gem) : `spree exec bundle ${args.join(' ')}`
      warnDeprecated('spree bundle', replacement)
      const ctx = detectProject()

      if (gem) {
        const opts = { yes: false, retry: `${replacement} --yes` }
        const extension = resolveExtension(gem)
        if (!extension) return addUncataloguedExtension(gem, undefined, opts)
        p.intro(pc.bgCyan(pc.black(` Spree ${extension.label} `)))
        await addExtension(ctx, extension, opts)
        p.outro('Done!')
        return
      }

      if (BUNDLE_WRITES.has(args[0]) && !runsFromSource(ctx.projectDir)) {
        p.cancel(
          [
            `This project runs the prebuilt Spree image, which does not load gems from ./${findApiDir(ctx.projectDir)}, so ${pc.bold(`bundle ${args[0]}`)} would change nothing.`,
            `Install extensions with ${pc.bold('spree add <extension>')}, which ejects the project first.`,
            `For anything else, ask the developer to agree to ${pc.bold('spree eject')} before running it.`,
          ].join('\n'),
        )
        process.exit(1)
      }

      await dockerComposeExecOrRun(bundleCommand(args), ctx.projectDir, {
        edgeHint: 'the edge stack heals gem drift on boot',
      })
    })
}
