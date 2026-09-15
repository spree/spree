import * as p from '@clack/prompts'
import { Command } from 'commander'
import getPort, { portNumbers } from 'get-port'
import pc from 'picocolors'
import { DEFAULT_SPREE_PORT } from './constants.js'
import { runPrompts } from './prompts.js'
import { scaffold } from './scaffold.js'
import type { PackageManager } from './types.js'
import { detectPackageManager } from './utils.js'

const program = new Command()
  .name('create-spree-app')
  .description('Create a new Spree Commerce project')
  .argument('[directory]', 'project directory')
  .option('--no-storefront', 'skip Next.js storefront setup')
  .option(
    '--react-dashboard',
    'no-op: the React Dashboard is always included (kept so existing scripts keep working)',
  )
  .option('--no-start', 'do not start Docker services')
  .option('--port <number>', 'port for the Spree server', String(DEFAULT_SPREE_PORT))
  .option('--use-npm', 'use npm as package manager')
  .option('--use-yarn', 'use yarn as package manager')
  .option('--use-pnpm', 'use pnpm as package manager')
  .action(async (directory: string | undefined, flags: Record<string, unknown>) => {
    p.intro(pc.bold('Create Spree App'))

    let packageManager: PackageManager = await detectPackageManager()
    if (flags.useNpm) packageManager = 'npm'
    if (flags.useYarn) packageManager = 'yarn'
    if (flags.usePnpm) packageManager = 'pnpm'
    if (packageManager === 'npm' && !flags.useNpm) {
      p.log.info(
        `Using npm (pnpm not found — run ${pc.cyan('corepack enable')} to get pnpm, which Spree recommends).`,
      )
    }

    try {
      const options = await runPrompts({
        directory,
        noStorefront: flags.storefront === false ? true : undefined,
        reactDashboard: flags.reactDashboard === true,
        noStart: flags.start === false ? true : undefined,
        packageManager,
      })

      const preferred = Number(flags.port)
      const port = await getPort({ port: portNumbers(preferred, preferred + 100) })
      if (port !== preferred) {
        p.log.warn(`Port ${preferred} is in use, using port ${pc.bold(String(port))} instead.`)
      }

      // Mailpit publishes both ports on the host, so another Spree project or
      // any local mail catcher takes them. Compose fails on a bound port with
      // a raw daemon error minutes into the run — after the image pull — so
      // probe them here like the web port rather than letting that happen.
      const mailpitSmtpPort = await getPort({ port: portNumbers(1025, 1125) })
      const mailpitUiPort = await getPort({ port: portNumbers(8025, 8125) })
      for (const [label, preferredPort, resolved] of [
        ['Mailpit SMTP', 1025, mailpitSmtpPort],
        ['Mailpit UI', 8025, mailpitUiPort],
      ] as const) {
        if (resolved !== preferredPort) {
          p.log.warn(
            `${label} port ${preferredPort} is in use, using port ${pc.bold(String(resolved))} instead.`,
          )
        }
      }

      await scaffold({ ...options, port, mailpitSmtpPort, mailpitUiPort })

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
