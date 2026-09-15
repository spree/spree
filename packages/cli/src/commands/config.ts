import fs from 'node:fs'
import path from 'node:path'
import * as p from '@clack/prompts'
import { type Command, Option } from 'commander'
import pc from 'picocolors'
import {
  type AdminClient,
  type CredentialFlags,
  clientFor,
  withCredentialFlags,
} from '../api/client.js'
import { handleApiError } from '../api/output.js'
import {
  type ApplyResult,
  applyPlan,
  ConfigValidationError,
  introspect,
  loadConfig,
  missingScopes,
  planConfig,
  planHasChanges,
  planHasDeletes,
  planHasErrors,
  planToJson,
  presentSections,
  renderConfigYaml,
  renderPlan,
  renderReport,
  reportHasFailures,
  SECTION_NAMES,
  type SectionName,
} from '../config/index.js'
import { detectProject } from '../context.js'

export const DEFAULT_CONFIG_FILE = 'spree.config.yml'

interface PlanFlags extends CredentialFlags {
  config?: string
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

function withPlanFlags(command: Command): Command {
  return withCredentialFlags(command)
    .option(
      '-c, --config <file>',
      `configuration file (default: ${DEFAULT_CONFIG_FILE} in the project)`,
    )
    .option(
      '--prune <sections>',
      'comma-separated sections whose live records absent from the file are deleted',
    )
    .option('--verbose', 'list unchanged records too')
    .addOption(
      new Option('--format <format>', 'output format').choices(['text', 'json']).default('text'),
    )
}

/** `spree.config.yml` at the project root when inside a project, else in the working directory. */
export function resolveConfigFile(flag: string | undefined, cwd = process.cwd()): string {
  if (flag) return path.resolve(cwd, flag)
  try {
    return path.join(detectProject(cwd).projectDir, DEFAULT_CONFIG_FILE)
  } catch {
    return path.join(cwd, DEFAULT_CONFIG_FILE)
  }
}

/** Parses `--prune a,b`, refusing names that are not sections. */
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

function readConfigOrExit(file: string) {
  try {
    return loadConfig(file)
  } catch (error) {
    if (error instanceof ConfigValidationError) {
      process.stderr.write(`${pc.red('error:')} ${file} is not a valid configuration file:\n`)
      for (const issue of error.issues) {
        process.stderr.write(
          `  ${issue.path}${issue.line ? pc.dim(` (line ${issue.line})`) : ''}: ${issue.message}\n`,
        )
      }
      process.exit(2)
    }
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
      process.stderr.write(
        `${pc.red('error:')} ${file} does not exist. Pass --config <file> or run \`spree config introspect --out ${DEFAULT_CONFIG_FILE}\` to create one.\n`,
      )
      process.exit(2)
    }
    throw error
  }
}

/** Refuses a deploy whose key lacks a section's write scope, naming the fix. */
async function ensureScopes(client: AdminClient, sections: SectionName[]): Promise<void> {
  const missing = await missingScopes(client, sections)
  if (!missing || missing.length === 0) return
  process.stderr.write(
    `${pc.red('error:')} this key lacks the scopes the file needs: ${missing.join(', ')}\n` +
      `${pc.dim(`  spree api-key create --type secret --scopes ${missing.join(',')}`)}\n` +
      `${pc.dim('  then pass it via --api-key <sk_...> or export SPREE_API_KEY=<sk_...>')}\n`,
  )
  process.exit(2)
}

export function registerConfigCommand(program: Command): void {
  const config = program
    .command('config')
    .description(
      'Declarative store configuration: validate, diff, deploy and introspect spree.config.yml',
    )

  config.addHelpText(
    'after',
    [
      '',
      'Examples:',
      '  spree config validate                          # schema check, no network',
      '  spree config diff                              # what deploy would change (exit 1 when something would)',
      '  spree config deploy --prune products           # apply, deleting products missing from the file',
      '  spree config deploy --fail-on-delete --yes     # CI: refuse any delete, skip the prompt',
      '  spree config introspect --out spree.config.yml # write the live configuration to a file',
    ].join('\n'),
  )

  config
    .command('validate')
    .description('Check the file against the schema without touching the network')
    .option(
      '-c, --config <file>',
      `configuration file (default: ${DEFAULT_CONFIG_FILE} in the project)`,
    )
    .action((flags: { config?: string }) => {
      const file = resolveConfigFile(flags.config)
      const loaded = readConfigOrExit(file)
      process.stdout.write(
        `${pc.green('✓')} ${file} is valid (${loaded.sections.length ? loaded.sections.join(', ') : 'no sections'})\n`,
      )
    })

  withPlanFlags(
    config
      .command('diff')
      .description('Show what deploy would change; exits 1 when the store differs from the file'),
  ).action(async (flags: PlanFlags) => {
    const file = resolveConfigFile(flags.config)
    const { config: loaded } = readConfigOrExit(file)
    const prune = parseSections(flags.prune, '--prune')
    let baseUrl: string | undefined
    try {
      const { client, credentials } = await clientFor(flags)
      baseUrl = credentials.baseUrl
      const plan = await planConfig(loaded, client, { prune })
      if (flags.format === 'json') process.stdout.write(`${JSON.stringify(planToJson(plan))}\n`)
      else process.stdout.write(`${renderPlan(plan, { verbose: flags.verbose })}\n`)
      if (planHasErrors(plan)) process.exitCode = 2
      else if (planHasChanges(plan)) process.exitCode = 1
    } catch (error) {
      handleApiError(error, { baseUrl })
    }
  })

  withPlanFlags(
    config
      .command('deploy')
      .description('Reconcile the store with the file: show the diff, confirm, apply'),
  )
    .option('--fail-on-delete', 'refuse to run when the plan contains a delete')
    .option(
      '-y, --yes',
      'apply without asking (implied by --format json and by a non-interactive run)',
    )
    .action(async (flags: DeployFlags) => {
      const file = resolveConfigFile(flags.config)
      const { config: loaded } = readConfigOrExit(file)
      const prune = parseSections(flags.prune, '--prune')
      const json = flags.format === 'json'
      let baseUrl: string | undefined
      try {
        const { client, credentials } = await clientFor(flags)
        baseUrl = credentials.baseUrl
        await ensureScopes(client, presentSections(loaded))
        const plan = await planConfig(loaded, client, { prune })

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
            process.stdout.write(
              `${JSON.stringify({ plan: planToJson(plan), ...outcome, results })}\n`,
            )
          } else if (outcome.results?.length)
            process.stdout.write(`${renderReport({ results: outcome.results })}\n`)
          else if (outcome.reason) process.stderr.write(`${pc.red('error:')} ${outcome.reason}\n`)
          else
            process.stderr.write(
              `${pc.green('✓')} ${credentials.baseUrl} already matches ${file}.\n`,
            )
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

        const report = await applyPlan(plan)
        finish({ applied: true, results: report.results }, reportHasFailures(report) ? 1 : 0)
      } catch (error) {
        handleApiError(error, { baseUrl })
      }
    })

  withCredentialFlags(
    config
      .command('introspect')
      .description('Write the live configuration as YAML (stdout, or --out <file>)'),
  )
    .option('-o, --out <file>', 'write to this file instead of stdout')
    .option(
      '--include <sections>',
      `comma-separated sections to read (default: everything but products and customers)`,
    )
    .action(async (flags: IntrospectFlags) => {
      const include = parseSections(flags.include, '--include')
      let baseUrl: string | undefined
      try {
        const { client, credentials } = await clientFor(flags)
        baseUrl = credentials.baseUrl
        const result = await introspect(client, include.length ? { include } : {})
        const yaml = renderConfigYaml(result)
        if (flags.out) {
          const file = path.resolve(flags.out)
          fs.writeFileSync(file, yaml)
          process.stderr.write(`${pc.green('✓')} wrote ${file} from ${credentials.baseUrl}\n`)
        } else {
          process.stdout.write(yaml)
        }
      } catch (error) {
        handleApiError(error, { baseUrl })
      }
    })
}
