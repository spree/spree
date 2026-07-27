import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { detectProject, hasMonorepoSpreePath } from '../context.js'
import { dockerComposeCapture, dockerComposeExecOrRun, isServiceRunning } from '../docker.js'

// Sequences bundle update + db:migrate + spree:upgrade rake. Flags map
// to env vars on the inner rake task: --plan → DRY_RUN, --step → STEP,
// --to → TO. --plan and --step skip the bundle + migrate pre-steps.
export function registerUpgradeCommand(program: Command): void {
  program
    .command('upgrade')
    .description('Walk through a Spree version upgrade (bundle + migrate + spree:upgrade)')
    .option('--plan', 'print the plan via spree:upgrade DRY_RUN=1; skip bundle + migrate')
    .option('--step <id>', 'run a single rake step by id (skips bundle + migrate)')
    .option(
      '--to <version>',
      'explicit target version (auto-detected from installed gem otherwise)',
    )
    .option('--yes', 'skip prompts on automated steps')
    .action(async (flags: { plan?: boolean; step?: string; to?: string; yes?: boolean }) => {
      const ctx = detectProject()
      await assertUpgradeable(ctx.projectDir)

      const skipUniversal = Boolean(flags.plan || flags.step)

      if (!skipUniversal) {
        await runBundleUpdate(ctx.projectDir, flags)
        await runMigrate(ctx.projectDir, flags)
      }

      await runRakeUpgrade(ctx.projectDir, flags)

      if (!flags.plan) printPostUpgradeReminder(ctx.projectDir)
    })
}

// Upgrade migrates the DB and runs spree:upgrade rake against the project's
// REAL Postgres + warm bundle_cache. A one-off `compose run` reaches the same
// named volumes (`run`'s depends_on cold-starts postgres, like db:reset), so
// each step falls back to one when web is down. Cheap pre-checks: monorepo-edge
// + the compose stack being inspectable at all.
async function assertUpgradeable(projectDir: string): Promise<void> {
  const refuse = (lines: string[]): never => {
    p.cancel(lines.join('\n'))
    process.exit(1)
  }

  if (hasMonorepoSpreePath(projectDir)) {
    refuse([
      'This is a monorepo edge project (SPREE_PATH set in .env).',
      `Run the upgrade from the monorepo root with ${pc.bold('pnpm server:*')} — the`,
      'project-local docker-compose.yml is not the running config here.',
    ])
  }

  try {
    await isServiceRunning('web', projectDir)
  } catch (err) {
    // `compose ps` itself failed: broken/stale compose, daemon down, unknown
    // service. Point home instead of dumping the raw env-file error. (Backstop
    // for a stale backend/ that slipped past detectProject re-rooting.)
    refuse([
      'Could not inspect the Docker stack from this directory.',
      `  ${pc.dim(String((err as Error).message).split('\n')[0])}`,
      '',
      `Run ${pc.bold('spree upgrade')} from your project root (the directory holding the`,
      '.env with SECRET_KEY_BASE), and make sure Docker is running.',
    ])
  }
}

async function runBundleUpdate(projectDir: string, flags: { yes?: boolean }): Promise<void> {
  if (!flags.yes) {
    const confirmed = await p.confirm({
      message: 'Run `bundle update` to bump Spree gems?',
      initialValue: true,
    })
    if (p.isCancel(confirmed)) {
      p.cancel('Upgrade aborted.')
      process.exit(0)
    }
    if (!confirmed) {
      p.log.info('Skipping `bundle update`.')
      return
    }
  }

  // Scope to spree* gems to avoid surprise major bumps on unrelated deps.
  const spreeGems = await detectSpreeGems(projectDir)
  if (spreeGems.length === 0) {
    throw new Error(
      'No Spree gems detected in Gemfile.lock. ' +
        'Confirm the project has `gem "spree"` (or `spree_core`/`spree_admin`) in its Gemfile.',
    )
  }

  p.log.step(pc.bold(`bundle update ${spreeGems.join(' ')}`))
  await dockerComposeExecOrRun(['bundle', 'update', ...spreeGems], projectDir)
}

export async function detectSpreeGems(projectDir: string): Promise<string[]> {
  try {
    // Filter in JS rather than piping through grep: `bundle list` exits 0 even
    // with zero spree gems, so a nonzero exit unambiguously means bundler
    // itself errored (out-of-sync lockfile, un-checked-out git source) — no
    // exit-code disambiguation against grep's "no match" needed.
    const stdout = await dockerComposeCapture(['bundle', 'list', '--name-only'], projectDir)
    return stdout
      .split('\n')
      .map((line) => line.trim())
      .filter((line) => line.startsWith('spree'))
  } catch (err) {
    const e = err as { stderr?: string }
    // Surface bundler's error + the real next step instead of laundering it
    // into a misleading "No Spree gems detected".
    throw new Error(
      'Could not list gems in the web container — the bundle looks out of sync.\n' +
        'Run `spree bundle install` first, then re-run `spree upgrade`.' +
        (e.stderr?.trim() ? `\n\n${e.stderr.trim()}` : ''),
    )
  }
}

async function runMigrate(projectDir: string, flags: { yes?: boolean }): Promise<void> {
  if (!flags.yes) {
    const confirmed = await p.confirm({
      message: 'Install + run pending migrations?',
      initialValue: true,
    })
    if (p.isCancel(confirmed)) {
      p.cancel('Upgrade aborted.')
      process.exit(0)
    }
    if (!confirmed) {
      p.log.info('Skipping migrations.')
      return
    }
  }
  p.log.step(pc.bold('spree:install:migrations + db:migrate'))
  await dockerComposeExecOrRun(['bin/rails', 'spree:install:migrations', 'db:migrate'], projectDir)
}

async function runRakeUpgrade(
  projectDir: string,
  flags: { plan?: boolean; step?: string; to?: string },
): Promise<void> {
  // Flags map to env vars so prod (`STEP=channels rake spree:upgrade`) and dev share the same path.
  const env: Record<string, string> = {}
  if (flags.plan) env.DRY_RUN = '1'
  if (flags.step) env.STEP = flags.step
  if (flags.to) env.TO = flags.to

  p.log.step(pc.bold('spree:upgrade'))
  await dockerComposeExecOrRun(['bin/rake', 'spree:upgrade'], projectDir, { env })
}

// The backend upgrade never touches frontend source — SDK bumps go through
// the consumer's own PR/CI cycle. But we can detect the conventional
// create-spree-app storefront and tell the operator exactly what to bump.
export function sdkAdvisory(projectDir: string): string {
  const generic = 'Update @spree/sdk in any storefront or integration consuming the API'
  const pkgPath = path.join(projectDir, 'apps', 'storefront', 'package.json')
  if (!fs.existsSync(pkgPath)) return generic
  try {
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8')) as {
      dependencies?: Record<string, string>
      devDependencies?: Record<string, string>
    }
    const declared = pkg.dependencies?.['@spree/sdk'] ?? pkg.devDependencies?.['@spree/sdk']
    if (!declared) return generic
    return `Update @spree/sdk in apps/storefront (currently ${declared}) to the release matching the new Spree version`
  } catch {
    return generic
  }
}

function printPostUpgradeReminder(projectDir: string): void {
  p.note(
    [
      `The manifest only ran ${pc.bold('rake-automatable')} steps.`,
      '',
      "Don't forget the manual parts from the upgrade doc:",
      `  ${pc.dim('- Schedule Spree::StockReservations::ExpireJob (cron)')}`,
      `  ${pc.dim(`- ${sdkAdvisory(projectDir)}`)}`,
      `  ${pc.dim('- Review behavior changes (cart, availability, payment-method types)')}`,
      `  ${pc.dim('- Audit custom decorators against renamed APIs')}`,
      '',
      `Full checklist: ${pc.cyan('https://spreecommerce.org/docs/developer/upgrades')}`,
    ].join('\n'),
    'Next steps',
  )
}
