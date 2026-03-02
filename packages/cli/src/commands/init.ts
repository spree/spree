import type { Command } from 'commander'
import * as p from '@clack/prompts'
import pc from 'picocolors'
import { execaCommand } from 'execa'
import { platform } from 'node:os'
import { detectProject } from '../context.js'
import { dockerCompose, railsRunner } from '../docker.js'
import { DEFAULT_ADMIN_EMAIL, DEFAULT_ADMIN_PASSWORD } from '../constants.js'

const HEALTH_CHECK_INTERVAL_MS = 3000
const HEALTH_CHECK_TIMEOUT_MS = 120_000

export function registerInitCommand(program: Command): void {
  program
    .command('init')
    .description('First-run setup: start services, configure API key, load sample data')
    .option('--no-sample-data', 'skip loading sample data')
    .option('--no-open', 'skip opening browser')
    .action(async (flags: { sampleData: boolean; open: boolean }) => {
      const ctx = detectProject()

      const s = p.spinner()
      s.start('Starting Docker services...')
      await dockerCompose(['up', '-d'], ctx.projectDir)
      s.stop('Docker services started.')

      s.start('Waiting for Spree to be ready...')
      await waitForHealthy(ctx.port)
      s.stop('Spree is ready.')

      s.start('Configuring API key...')
      const apiKey = await fetchApiKey(ctx.projectDir)
      s.stop(`API key: ${pc.cyan(apiKey)}`)

      if (flags.sampleData) {
        s.start('Loading sample data...')
        await dockerCompose(
          ['exec', '-T', 'web', 'bin/rails', 'spree:load_sample_data'],
          ctx.projectDir,
        )
        s.stop('Sample data loaded.')
      }

      p.note(
        [
          '',
          pc.bold('Admin Dashboard'),
          `  ${pc.cyan(`http://localhost:${ctx.port}/admin`)}`,
          `  Email:    ${DEFAULT_ADMIN_EMAIL}`,
          `  Password: ${DEFAULT_ADMIN_PASSWORD}`,
          '',
          pc.bold('Store API'),
          `  ${pc.cyan(`http://localhost:${ctx.port}/api/v3/store`)}`,
          `  API Key: ${pc.cyan(apiKey)}`,
          '',
        ].join('\n'),
        'Your Spree store is ready!',
      )

      if (flags.open) {
        await openBrowser(`http://localhost:${ctx.port}/admin`)
      }
    })
}

async function waitForHealthy(port: number): Promise<void> {
  const url = `http://localhost:${port}/up`
  const start = Date.now()

  while (Date.now() - start < HEALTH_CHECK_TIMEOUT_MS) {
    try {
      const res = await fetch(url)
      if (res.ok) return
    } catch {
      // not ready yet
    }
    await new Promise((resolve) => setTimeout(resolve, HEALTH_CHECK_INTERVAL_MS))
  }

  throw new Error(`Spree did not become healthy within ${HEALTH_CHECK_TIMEOUT_MS / 1000}s`)
}

async function fetchApiKey(projectDir: string): Promise<string> {
  const script = [
    'store = Spree::Store.default;',
    'key = store.api_keys.active.publishable.first ||',
    "  store.api_keys.create!(name: 'Default', key_type: 'publishable');",
    'print key.plaintext_token',
  ].join(' ')

  const stdout = await railsRunner(script, projectDir)

  const match = stdout.match(/pk_[A-Za-z0-9_-]+/)
  if (!match) {
    throw new Error(`Could not extract API key from Rails output: ${stdout}`)
  }
  return match[0]
}

async function openBrowser(url: string): Promise<void> {
  const os = platform()
  const cmd = os === 'darwin' ? 'open' : os === 'win32' ? 'start' : 'xdg-open'

  try {
    await execaCommand(`${cmd} ${url}`, { stdio: 'ignore' })
  } catch {
    // best-effort
  }
}
