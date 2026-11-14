import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import {
  type ApplyReport,
  type ApplyResult,
  applyPlan,
  applyProvisioning,
  assertPrunable,
  introspect,
  loadSeeds,
  missingScopes,
  type PlannedRun,
  planHasChanges,
  planHasDeletes,
  planHasErrors,
  planSeeds,
  planToJson,
  renderPlan,
  renderReport,
  renderSeedsYaml,
  reportHasFailures,
  SECTION_NAMES,
  type SectionName,
  SeedsValidationError,
  type SpreeSeeds,
  storeDefaults,
} from '@spree/seeds/node'
import { type Command, Option } from 'commander'
import pc from 'picocolors'
import {
  type AdminClient,
  type CredentialFlags,
  clientFor,
  withCredentialFlags,
} from '../api/client.js'
import { handleApiError } from '../api/output.js'
import { SEED_TASK } from '../backend.js'
import { detectProject } from '../context.js'
import { captureTask } from '../docker.js'

export const DEFAULT_SEEDS_FILE = 'spree.seeds.yml'

interface PlanFlags extends CredentialFlags {
  file?: string
  dryRun?: boolean
  prune?: string
  format: 'text' | 'json'
  verbose?: boolean
}

interface DeployFlags extends PlanFlags {
  failOnDelete?: boolean
  yes?: boolean
}

/** What a deploy reports once the plan is known: refused, nothing to do, or applied. */
interface DeployOutcome {
  applied: boolean
  reason?: string
  results?: ApplyResult[]
}

interface IntrospectFlags extends CredentialFlags {
  out?: string
  include?: string
}

function withFileFlag(command: Command): Command {
  return command.option(
    '-f, --file <file>',
    `seeds file (default: ${DEFAULT_SEEDS_FILE} in the project)`,
  )
}

function withPlanFlags(command: Command): Command {
  return withFileFlag(withCredentialFlags(command))
    .option(
      '--prune <sections>',
      'comma-separated sections whose live records absent from the file are deleted',
    )
    .option('--verbose', 'list unchanged records too')
    .addOption(
      new Option('--format <format>', 'output format').choices(['text', 'json']).default('text'),
    )
}

/** `spree.seeds.yml` at the project root when inside a project, else in the working directory. */
export function resolveSeedsFile(flag: string | undefined, cwd = process.cwd()): string {
  if (flag) return path.resolve(cwd, flag)
  try {
    return path.join(detectProject(cwd).projectDir, DEFAULT_SEEDS_FILE)
  } catch {
    return path.join(cwd, DEFAULT_SEEDS_FILE)
  }
}

/** Parses `--prune a,b`, refusing names that are not sections or may not be pruned. */
export function parsePrune(value: string | undefined): SectionName[] {
  const sections = parseSections(value, '--prune')
  assertPrunable(sections)
  return sections
}

/** Parses a comma-separated section list, refusing names that are not sections. */
export function parseSections(value: string | undefined, flag: string): SectionName[] {
  if (!value) return []
  const names = value
    .split(',')
    .map((name) => name.trim())
    .filter(Boolean)
  const unknown = names.filter((name) => !(SECTION_NAMES as readonly string[]).includes(name))
  if (unknown.length) {
    throw new Error(
      `Unknown section${unknown.length === 1 ? '' : 's'} in ${flag}: ${unknown.join(', ')}. Sections: ${SECTION_NAMES.join(', ')}`,
    )
  }
  return names as SectionName[]
}

function readSeedsOrExit(file: string) {
  try {
    return loadSeeds(file)
  } catch (error) {
    if (error instanceof SeedsValidationError) {
      process.stderr.write(`${pc.red('error:')} ${file} is not a valid seeds file:\n`)
      for (const issue of error.issues) {
        process.stderr.write(
          `  ${issue.path}${issue.line ? pc.dim(` (line ${issue.line})`) : ''}: ${issue.message}\n`,
        )
      }
      process.exit(2)
    }
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
      process.stderr.write(
        `${pc.red('error:')} ${file} does not exist. Pass --file <file> or run \`spree seed introspect --out ${DEFAULT_SEEDS_FILE}\` to create one.\n`,
      )
      process.exit(2)
    }
    throw error
  }
}

/** Refuses a deploy whose key lacks a scope the file needs, naming the fix. */
async function ensureScopes(client: AdminClient, config: SpreeSeeds): Promise<void> {
  const missing = await missingScopes(client, config)
  if (!missing || missing.length === 0) return
  process.stderr.write(
    `${pc.red('error:')} this key lacks the scopes the file needs: ${missing.join(', ')}\n` +
      `${pc.dim(`  spree api-key create --type secret --scopes ${missing.join(',')}`)}\n` +
      `${pc.dim('  then pass it via --api-key <sk_...> or export SPREE_API_KEY=<sk_...>')}\n`,
  )
  process.exit(2)
}

/**
 * Plans a configuration against the store, shows the diff, confirms and
 * applies it. `label` names what the store is compared with in messages.
 */
async function deploy(
  flags: DeployFlags,
  label: string,
  load: (client: AdminClient) => Promise<SpreeSeeds>,
  {
    createOnly = false,
    apply = (plan) => applyPlan(plan),
  }: {
    createOnly?: boolean
    /** How the confirmed plan is applied; the plan itself by default. */
    apply?: (plan: PlannedRun) => Promise<ApplyReport>
  } = {},
): Promise<void> {
  const prune = parsePrune(flags.prune)
  const json = flags.format === 'json'
  let baseUrl: string | undefined
  try {
    const { client, credentials } = await clientFor(flags)
    baseUrl = credentials.baseUrl
    const loaded = await load(client)
    await ensureScopes(client, loaded)
    const plan = await planSeeds(loaded, client, { prune, createOnly })

    // One output path whatever happens: JSON gets the plan plus the
    // outcome, text gets the diff on stderr and the outcome on stdout.
    const finish = (outcome: DeployOutcome, exitCode: number): never => {
      if (json) {
        const results = outcome.results?.map((result) => ({
          path: result.operation.path,
          key: result.operation.key,
          kind: result.operation.kind,
          status: result.status,
          message: result.message,
          details: result.details,
        }))
        process.stdout.write(`${JSON.stringify({ plan: planToJson(plan), ...outcome, results })}\n`)
      } else if (outcome.results?.length)
        process.stdout.write(`${renderReport({ results: outcome.results })}\n`)
      else if (outcome.reason) process.stderr.write(`${pc.red('error:')} ${outcome.reason}\n`)
      else
        process.stderr.write(`${pc.green('✓')} ${credentials.baseUrl} already matches ${label}.\n`)
      process.exit(exitCode)
    }

    if (!json) process.stderr.write(`${renderPlan(plan, { verbose: flags.verbose })}\n\n`)
    if (planHasErrors(plan))
      finish({ applied: false, reason: 'the plan has errors; nothing was written.' }, 2)
    if (flags.failOnDelete && planHasDeletes(plan)) {
      finish(
        {
          applied: false,
          reason: 'the plan contains deletes and --fail-on-delete is set; nothing was written.',
        },
        1,
      )
    }
    if (!planHasChanges(plan)) finish({ applied: true, results: [] }, 0)
    // JSON output is for scripts, which cannot answer a prompt.
    if (!flags.yes && !json && process.stdin.isTTY) {
      const answer = await p.confirm({
        message: `Apply these changes to ${credentials.baseUrl}?`,
        initialValue: true,
      })
      if (p.isCancel(answer) || !answer) {
        p.cancel('Nothing was written.')
        process.exit(1)
      }
    }

    const report = await apply(plan)
    finish({ applied: true, results: report.results }, reportHasFailures(report) ? 1 : 0)
  } catch (error) {
    handleApiError(error, { baseUrl })
  }
}

/** The project a run without `--base-url` or `--profile` seeds, when the command runs inside one. */
function localProject(flags: CredentialFlags): string | null {
  if (flags.baseUrl || flags.profile || process.env.SPREE_BASE_URL) return null
  try {
    return detectProject().projectDir
  } catch {
    return null
  }
}

/** Shows what a deploy of the file would change; exits 1 when the store differs. */
async function dryRun(flags: PlanFlags, loaded: SpreeSeeds): Promise<void> {
  const prune = parsePrune(flags.prune)
  let baseUrl: string | undefined
  try {
    const { client, credentials } = await clientFor(flags)
    baseUrl = credentials.baseUrl
    const plan = await planSeeds(loaded, client, { prune })
    if (flags.format === 'json') process.stdout.write(`${JSON.stringify(planToJson(plan))}\n`)
    else process.stdout.write(`${renderPlan(plan, { verbose: flags.verbose })}\n`)
    if (planHasErrors(plan)) process.exitCode = 2
    else if (planHasChanges(plan)) process.exitCode = 1
  } catch (error) {
    handleApiError(error, { baseUrl })
  }
}

/**
 * Whether the store still waits for its first admin. The defaults a file may
 * refer to arrive with first-run setup, so the file is deployed after it.
 */
async function awaitsSetup(flags: CredentialFlags): Promise<boolean> {
  try {
    const { client } = await clientFor(flags)
    return (await client.auth.setupStatus()).setup_required === true
  } catch {
    return false
  }
}

async function seed(flags: DeployFlags): Promise<void> {
  const projectDir = localProject(flags)
  const file = resolveSeedsFile(flags.file)
  const quiet = flags.format === 'json'

  // The database seeds create what the Admin API cannot: the store itself,
  // its admin role and its first key. They only run where the project runs.
  if (projectDir && !flags.dryRun) {
    const s = quiet ? null : p.spinner()
    s?.start('Seeding database...')
    await captureTask(SEED_TASK, projectDir)
    s?.stop('Database seeded.')
  }

  if (!fs.existsSync(file) && projectDir && !flags.file) return
  const { config: loaded } = readSeedsOrExit(file)

  if (projectDir && (await awaitsSetup(flags))) {
    process.stderr.write(
      `${path.basename(file)} is deployed once first-run setup is done: finish setup in the dashboard, then run \`spree seed\` again.\n`,
    )
    return
  }

  if (flags.dryRun) await dryRun(flags, loaded)
  else await deploy(flags, file, async () => loaded)
}

export function registerSeedCommand(program: Command): void {
  const command = withPlanFlags(
    program
      .command('seed')
      .description(
        `Seed the store: run the database seeds, then deploy ${DEFAULT_SEEDS_FILE} through the Admin API`,
      ),
  )
    .option('--dry-run', 'show what would change and write nothing; exits 1 when the store differs')
    .option('--fail-on-delete', 'refuse to run when the plan contains a delete')
    .option(
      '-y, --yes',
      'apply without asking (implied by --format json and by a non-interactive run)',
    )
    .action(seed)

  command.addHelpText(
    'after',
    [
      '',
      'Examples:',
      '  spree seed                                   # seed the database, then deploy spree.seeds.yml',
      '  spree seed --dry-run                         # what would change (exit 1 when something would)',
      '  spree seed --prune products                  # also delete products missing from the file',
      '  spree seed --base-url <url> --api-key <key>  # seed another instance from the file',
      '  spree seed --fail-on-delete --yes            # CI: refuse any delete, skip the prompt',
      '  spree seed validate                          # check the file, no network',
      '  spree seed introspect --out spree.seeds.yml  # write the live store to a file',
      '  spree seed defaults                          # give a new store its defaults (setup does this for you)',
    ].join('\n'),
  )

  // Each subcommand takes its flags itself too, so they work on either side of its name.
  withFileFlag(
    command
      .command('validate')
      .description('Check the file against the schema without touching the network'),
  ).action((_flags: unknown, sub: Command) => {
    const file = resolveSeedsFile(sub.optsWithGlobals<PlanFlags>().file)
    const loaded = readSeedsOrExit(file)
    process.stdout.write(
      `${pc.green('✓')} ${file} is valid (${loaded.sections.length ? loaded.sections.join(', ') : 'no sections'})\n`,
    )
  })

  withCredentialFlags(
    command
      .command('defaults')
      .description(
        "Create the defaults every new store starts with, shaped by the store's country",
      ),
  )
    .option('--verbose', 'list unchanged records too')
    .addOption(
      new Option('--format <format>', 'output format').choices(['text', 'json']).default('text'),
    )
    .option('-y, --yes', 'apply without asking (implied by a non-interactive run)')
    .action(async (_flags: unknown, sub: Command) => {
      // Defaults the merchant has since changed are left alone: only what is
      // missing is created, through the same ordered deploy setup uses.
      await deploy(
        sub.optsWithGlobals<DeployFlags>(),
        'the store defaults',
        (client) => storeDefaults(client),
        { createOnly: true, apply: applyProvisioning },
      )
    })

  withCredentialFlags(
    command
      .command('introspect')
      .description('Write the live store as YAML (stdout, or --out <file>)'),
  )
    .option('-o, --out <file>', 'write to this file instead of stdout')
    .option(
      '--include <sections>',
      'comma-separated sections to read (default: everything but products and customers)',
    )
    .action(async (_flags: unknown, sub: Command) => {
      const flags = sub.optsWithGlobals<IntrospectFlags>()
      const include = parseSections(flags.include, '--include')
      let baseUrl: string | undefined
      try {
        const { client, credentials } = await clientFor(flags)
        baseUrl = credentials.baseUrl
        const result = await introspect(client, include.length ? { include } : {})
        const yaml = renderSeedsYaml(result)
        if (flags.out) {
          const out = path.resolve(flags.out)
          fs.writeFileSync(out, yaml)
          process.stderr.write(`${pc.green('✓')} wrote ${out} from ${credentials.baseUrl}\n`)
        } else {
          process.stdout.write(yaml)
        }
      } catch (error) {
        handleApiError(error, { baseUrl })
      }
    })
}
