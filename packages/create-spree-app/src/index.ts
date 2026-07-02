import * as p from '@clack/prompts'
import { Command } from 'commander'
import getPort, { portNumbers } from 'get-port'
import pc from 'picocolors'
import { DEFAULT_MEILISEARCH_PORT, DEFAULT_SPREE_DB_PORT, DEFAULT_SPREE_PORT } from './constants.js'
import { runPrompts } from './prompts.js'
import { scaffold } from './scaffold.js'
import type { PackageManager } from './types.js'
import { detectPackageManager } from './utils.js'

const program = new Command()
  .name('create-spree-app')
  .description('Create a new Spree Commerce project')
  .argument('[directory]', 'project directory')
  .option('--no-storefront', 'skip Next.js storefront setup')
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
        noStorefront: flags.storefront === false ? true : undefined,
        noSampleData: flags.sampleData === false ? true : undefined,
        noStart: flags.start === false ? true : undefined,
        packageManager,
      })

      const preferred = Number(flags.port)
      const port = await getPort({ port: portNumbers(preferred, preferred + 100) })
      if (port !== preferred) {
        p.log.warn(`Port ${preferred} is in use, using port ${pc.bold(String(port))} instead.`)
      }

      // Postgres and Meilisearch host ports are picked free at scaffold time
      // and written into .env, so projects created side by side (or next to a
      // warm stack of another project) never fight over the defaults.
      const dbPort = await getPort({
        port: portNumbers(DEFAULT_SPREE_DB_PORT, DEFAULT_SPREE_DB_PORT + 100),
        exclude: [port],
      })
      if (dbPort !== DEFAULT_SPREE_DB_PORT) {
        p.log.warn(
          `Port ${DEFAULT_SPREE_DB_PORT} is in use, publishing Postgres on port ${pc.bold(String(dbPort))} instead.`,
        )
      }
      const meilisearchPort = await getPort({
        port: portNumbers(DEFAULT_MEILISEARCH_PORT, DEFAULT_MEILISEARCH_PORT + 100),
        exclude: [port, dbPort],
      })
      if (meilisearchPort !== DEFAULT_MEILISEARCH_PORT) {
        p.log.warn(
          `Port ${DEFAULT_MEILISEARCH_PORT} is in use, publishing Meilisearch on port ${pc.bold(String(meilisearchPort))} instead.`,
        )
      }

      await scaffold({ ...options, port, dbPort, meilisearchPort })

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
