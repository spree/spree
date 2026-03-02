import { Command } from 'commander'
import * as p from '@clack/prompts'
import pc from 'picocolors'
import getPort, { portNumbers } from 'get-port'
import { runPrompts } from './prompts.js'
import { scaffold } from './scaffold.js'
import { detectPackageManager } from './utils.js'
import { DEFAULT_SPREE_PORT } from './constants.js'
import type { PackageManager } from './types.js'

const program = new Command()
  .name('create-spree-app')
  .description('Create a new Spree Commerce project')
  .argument('[directory]', 'project directory')
  .option('--backend-only', 'skip storefront setup')
  .option('--no-sample-data', 'skip loading sample data')
  .option('--no-start', 'do not start Docker services')
  .option('--port <number>', 'port for the Spree backend', String(DEFAULT_SPREE_PORT))
  .option('--use-npm', 'use npm as package manager')
  .option('--use-yarn', 'use yarn as package manager')
  .option('--use-pnpm', 'use pnpm as package manager')
  .action(async (directory: string | undefined, flags: Record<string, unknown>) => {
    p.intro(pc.bold('Create Spree App'))

    let packageManager: PackageManager = detectPackageManager()
    if (flags.useNpm) packageManager = 'npm'
    if (flags.useYarn) packageManager = 'yarn'
    if (flags.usePnpm) packageManager = 'pnpm'

    try {
      const options = await runPrompts({
        directory,
        backendOnly: flags.backendOnly as boolean | undefined,
        noSampleData: flags.sampleData === false ? true : undefined,
        noStart: flags.start === false ? true : undefined,
        packageManager,
      })

      const preferred = Number(flags.port)
      const port = await getPort({ port: portNumbers(preferred, preferred + 100) })
      if (port !== preferred) {
        p.log.warn(`Port ${preferred} is in use, using port ${pc.bold(String(port))} instead.`)
      }

      await scaffold({ ...options, port })

      p.outro('Happy selling!')
    } catch (err) {
      if (err instanceof Error && err.message.includes('cancelled')) {
        p.cancel('Setup cancelled.')
        process.exit(0)
      }
      p.cancel(err instanceof Error ? err.message : 'An unexpected error occurred.')
      process.exit(1)
    }
  })

program.parse()
