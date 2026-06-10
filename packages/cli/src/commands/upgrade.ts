import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { execa } from 'execa'
import pc from 'picocolors'
import { detectProject } from '../context.js'
import { dockerComposeExec } from '../docker.js'

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

      const skipUniversal = Boolean(flags.plan || flags.step)

      if (!skipUniversal) {
        await runBundleUpdate(ctx.projectDir, flags)
        await runMigrate(ctx.projectDir, flags)
      }

      await runRakeUpgrade(ctx.projectDir, flags)

      if (!flags.plan) printPostUpgradeReminder(ctx.projectDir)
    })
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
  await dockerComposeExec(['bundle', 'update', ...spreeGems], projectDir)
}

async function detectSpreeGems(projectDir: string): Promise<string[]> {
  // Let exec failures (stack down, web service missing) bubble up — the
  // upgrade should fail loudly, not silently skip the gem bump.
  const { stdout } = await execa(
    'docker',
    [
      'compose',
      'exec',
      '-T',
      'web',
      'sh',
      '-c',
      "bundle list --name-only 2>/dev/null | grep '^spree' || true",
    ],
    { cwd: projectDir },
  )
  return stdout
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0 && line.startsWith('spree'))
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
  await dockerComposeExec(['bin/rails', 'spree:install:migrations', 'db:migrate'], projectDir)
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
  await dockerComposeExec(['bin/rake', 'spree:upgrade'], projectDir, { env })
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
