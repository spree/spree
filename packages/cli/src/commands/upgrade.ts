import * as p from '@clack/prompts'
import type { Command } from 'commander'
import pc from 'picocolors'
import { detectProject } from '../context.js'
import { dockerComposeExec } from '../docker.js'

/**
 * Register the `spree upgrade` command on the CLI program.
 *
 * Dev-friendly sequencer around the real upgrade flow:
 *
 *   1. bundle update   (universal — bumps spree_core etc.)
 *   2. db:migrate      (universal — applies the new gem's migrations)
 *   3. spree:upgrade   (version-specific — runs the rake-only manifest)
 *
 * On production, step 3 is what your deploy pipeline runs after `bundle
 * install` + `db:migrate` happen there. Steps 1 and 2 are handled by your
 * platform (Heroku release phase, K8s init container, Render auto-migrate,
 * Capistrano deploy hook), not by this CLI.
 *
 * Local dev: this command runs all three for you. On a clean stack the
 * total time is dominated by `bundle update` (network + native ext build).
 *
 * Flags map to env vars on the inner rake task so the same args work in
 * both surfaces:
 *
 *   --plan            DRY_RUN=1  (also skips steps 1 + 2)
 *   --step <id>       STEP=<id>
 *   --to <version>    TO=<version>
 *   --yes             no flag — skips the per-step prompt
 *
 * What this CLI deliberately does NOT do: schedule cron jobs, review
 * breaking changes, tune reservation TTLs. Those are in
 * docs/developer/upgrades/<v>.mdx and the manifest's `notes` text; we
 * print the docs URL at the end so the operator knows where to look.
 *
 * @param program - The Commander CLI program to register the command on.
 */
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

      // --plan and --step both opt out of the universal pre-steps:
      //   --plan: we're not running anything anyway.
      //   --step: the operator is retrying one rake step after a fix;
      //           bundle/migrate already happened in the original run.
      const skipUniversal = Boolean(flags.plan || flags.step)

      if (!skipUniversal) {
        await runBundleUpdate(ctx.projectDir, flags)
        await runMigrate(ctx.projectDir, flags)
      }

      await runRakeUpgrade(ctx.projectDir, flags)

      // Closing reminder: the manifest only covers rake-runnable steps.
      // Anything human (cron scheduling, breaking-change review) is in
      // the upgrade doc — point there so the operator doesn't forget.
      // Skipped on --plan because nothing actually ran — the "next steps"
      // reminder would be misleading.
      if (!flags.plan) printPostUpgradeReminder()
    })
}

async function runBundleUpdate(projectDir: string, flags: { yes?: boolean }): Promise<void> {
  if (!flags.yes) {
    const confirmed = await p.confirm({
      message: 'Run `bundle update` to bump Spree gems?',
      initialValue: true,
    })
    // Ctrl+C aborts the whole upgrade; "No" just skips this step.
    if (p.isCancel(confirmed)) {
      p.cancel('Upgrade aborted.')
      process.exit(0)
    }
    if (!confirmed) {
      p.log.info('Skipping `bundle update`.')
      return
    }
  }
  p.log.step(pc.bold('bundle update'))
  await dockerComposeExec(['bundle', 'update'], projectDir)
}

async function runMigrate(projectDir: string, flags: { yes?: boolean }): Promise<void> {
  if (!flags.yes) {
    const confirmed = await p.confirm({
      message: 'Install + run pending migrations?',
      initialValue: true,
    })
    // Ctrl+C aborts the whole upgrade; "No" just skips this step.
    // Skipping `db:migrate` is risky — the rake `spree:upgrade` step that
    // follows often assumes fresh schema. We let the user proceed anyway;
    // if rake fails they'll see why.
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
  // Compound rails invocation matches the canonical upgrade doc.
  await dockerComposeExec(['bin/rails', 'spree:install:migrations', 'db:migrate'], projectDir)
}

async function runRakeUpgrade(
  projectDir: string,
  flags: { plan?: boolean; step?: string; to?: string },
): Promise<void> {
  // Flags become env vars on the rake side. This is the contract that
  // keeps prod (operator typing `STEP=channels rake spree:upgrade`) and
  // dev (this CLI) using the same execution path.
  const env: Record<string, string> = {}
  if (flags.plan) env.DRY_RUN = '1'
  if (flags.step) env.STEP = flags.step
  if (flags.to) env.TO = flags.to

  p.log.step(pc.bold('spree:upgrade'))
  await dockerComposeExec(['bin/rake', 'spree:upgrade'], projectDir, { env })
}

function printPostUpgradeReminder(): void {
  p.note(
    [
      `The manifest only ran ${pc.bold('rake-automatable')} steps.`,
      '',
      "Don't forget the manual parts from the upgrade doc:",
      `  ${pc.dim('- Schedule Spree::StockReservations::ExpireJob (cron)')}`,
      `  ${pc.dim('- Review behavior changes (cart, availability, payment-method types)')}`,
      `  ${pc.dim('- Audit custom decorators against renamed APIs')}`,
      '',
      `Full checklist: ${pc.cyan('https://spreecommerce.org/docs/developer/upgrades')}`,
    ].join('\n'),
    'Next steps',
  )
}
