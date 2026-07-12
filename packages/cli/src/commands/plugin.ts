import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import * as p from '@clack/prompts'
import type { Command } from 'commander'
import { execaCommand } from 'execa'
import pc from 'picocolors'
import { render, type TemplateVars } from '../lib/template.js'

const TEMPLATE_RELATIVE_PATH = '../../templates/plugin'

interface PluginNewFlags {
  dashboard: boolean
  engine: boolean
  install: boolean
  force: boolean
  yes: boolean
  rubyName?: string
  moduleName?: string
  npmScope?: string
  author?: string
  authorEmail?: string
  license?: string
}

const LICENSES = ['MIT', 'Apache-2.0', 'BSD-3-Clause'] as const

export function registerPluginCommand(program: Command): void {
  const plugin = program
    .command('plugin')
    .description('Scaffold and manage Spree plugins (dashboard + Rails engine)')

  plugin
    .command('new')
    .description(
      'Scaffold a new Spree plugin monorepo (dashboard plugin half today; Rails engine coming soon)',
    )
    .argument('[name]', 'Plugin name (e.g. brands). If omitted, you will be prompted.')
    .option('--ruby-name <name>', 'Ruby gem name (default: spree_<name>)')
    .option(
      '--module-name <name>',
      'Ruby module / TS namespace (default: PascalCase of the gem name)',
    )
    .option('--npm-scope <scope>', 'npm scope, e.g. @acme (default: unscoped)')
    .option('--author <name>', 'Author name (default: git config user.name)')
    .option('--author-email <email>', 'Author email (default: git config user.email)')
    .option('--license <license>', `License: ${LICENSES.join(', ')} (default: MIT)`)
    .option(
      '-y, --yes',
      'Non-interactive: accept the default for every prompt not answered by a flag',
      false,
    )
    .option('--no-dashboard', 'Skip the dashboard plugin half')
    .option(
      '--no-engine',
      'Skip the Rails engine half (currently always skipped — engine support coming soon)',
    )
    .option('--no-install', 'Skip running pnpm install')
    .option('--force', 'Overwrite a non-empty destination directory')
    .action(async (nameArg: string | undefined, flags: PluginNewFlags) => {
      p.intro(pc.bgCyan(pc.black(' Spree Plugin Scaffolder ')))

      const answers = await collectAnswers(nameArg, flags)
      if (p.isCancel(answers)) {
        p.cancel('Scaffolding cancelled.')
        process.exit(0)
      }

      const dst = path.resolve(process.cwd(), answers.name)
      if (fs.existsSync(dst) && fs.readdirSync(dst).length > 0 && !flags.force) {
        p.cancel(
          `Destination ${pc.bold(dst)} is not empty. Choose a different name or rerun with ${pc.cyan('--force')}.`,
        )
        process.exit(1)
      }

      const vars = buildVars(answers)
      const templateSrc = resolveTemplatePath()

      const s = p.spinner()
      s.start(`Scaffolding ${pc.cyan(answers.name)}...`)
      try {
        render({
          src: templateSrc,
          dst,
          vars,
          skip: buildSkipPredicate(answers),
          force: flags.force,
        })
      } catch (err) {
        s.stop('Scaffolding failed.')
        p.log.error(err instanceof Error ? err.message : String(err))
        process.exit(1)
      }
      s.stop(`Created ${pc.cyan(dst)}`)

      if (flags.install) {
        await runInstall(dst, answers)
      } else {
        p.log.info(pc.dim('Skipping dependency install — run them yourself when ready.'))
      }

      printNextSteps(answers, dst, flags.install)
      p.outro('Happy hacking!')
    })
}

// ---------------------------------------------------------------------------
// Prompts + flag parsing
// ---------------------------------------------------------------------------

interface Answers {
  name: string
  rubyName: string
  moduleName: string
  npmScope: string
  authorName: string
  authorEmail: string
  license: string
  includeDashboard: boolean
  includeEngine: boolean
}

async function collectAnswers(
  nameArg: string | undefined,
  flags: PluginNewFlags,
): Promise<Answers | symbol> {
  const validateName = (value: string | undefined): string | undefined => {
    if (!value) return 'Required'
    if (!/^[a-z][a-z0-9-]*$/.test(value)) {
      return 'Use lowercase letters, digits, and dashes (e.g. "brands" or "loyalty-points")'
    }
    return undefined
  }

  if (nameArg !== undefined) {
    const problem = validateName(nameArg)
    if (problem) {
      p.log.error(`Invalid plugin name ${pc.bold(nameArg)}: ${problem}`)
      process.exit(2)
    }
  }

  if (nameArg === undefined && flags.yes) {
    p.log.error('Pass the plugin name as an argument when using --yes: spree plugin new <name> -y')
    process.exit(2)
  }

  const name =
    nameArg ??
    (await p.text({
      message: 'Plugin name',
      placeholder: 'brands',
      validate: validateName,
    }))
  if (p.isCancel(name)) return name as symbol

  // Every prompt below can be pre-answered by a flag; --yes accepts the
  // default for whatever the flags leave unanswered.
  const rubyDefault = `spree_${(name as string).replace(/-/g, '_')}`
  const rubyName = await resolveField({
    flag: '--ruby-name',
    flagValue: flags.rubyName,
    fallback: rubyDefault,
    yes: flags.yes,
    validate: (value) =>
      value && /^[a-z][a-z0-9_]*$/.test(value)
        ? undefined
        : 'Use lowercase letters, digits, and underscores (e.g. "spree_brands")',
    prompt: () =>
      p.text({
        message: 'Ruby gem name',
        placeholder: rubyDefault,
        initialValue: rubyDefault,
        validate: (value) =>
          value && /^[a-z][a-z0-9_]*$/.test(value)
            ? undefined
            : 'Use lowercase letters, digits, and underscores (e.g. "spree_brands")',
      }),
  })
  if (p.isCancel(rubyName)) return rubyName as symbol

  const moduleDefault = pascalCase(rubyName as string)
  const moduleName = await resolveField({
    flag: '--module-name',
    flagValue: flags.moduleName,
    fallback: moduleDefault,
    yes: flags.yes,
    validate: (value) =>
      value && /^[A-Z][A-Za-z0-9]*$/.test(value) ? undefined : 'PascalCase (e.g. "SpreeBrands")',
    prompt: () =>
      p.text({
        message: 'Ruby module / TS namespace',
        placeholder: moduleDefault,
        initialValue: moduleDefault,
        validate: (value) =>
          value && /^[A-Z][A-Za-z0-9]*$/.test(value)
            ? undefined
            : 'PascalCase (e.g. "SpreeBrands")',
      }),
  })
  if (p.isCancel(moduleName)) return moduleName as symbol

  const validateScope = (value: string | undefined): string | undefined =>
    !value || /^@[a-z0-9][a-z0-9-]*$/.test(value)
      ? undefined
      : 'Must start with @ and contain lowercase letters/digits/dashes'
  const npmScope = await resolveField({
    flag: '--npm-scope',
    flagValue: flags.npmScope,
    fallback: '',
    yes: flags.yes,
    validate: validateScope,
    prompt: () =>
      p.text({
        message: 'npm scope (optional, leave blank for unscoped)',
        placeholder: '@my-org',
        initialValue: '',
        validate: validateScope,
      }),
  })
  if (p.isCancel(npmScope)) return npmScope as symbol

  // Author identity defaults to the local git config — the same values a
  // `git commit` in this shell would stamp.
  const gitAuthor = flags.author === undefined ? await gitConfigValue('user.name') : undefined
  const authorName = await resolveField({
    flag: '--author',
    flagValue: flags.author,
    fallback: gitAuthor,
    yes: flags.yes,
    validate: (value) => (value ? undefined : 'Required'),
    prompt: () =>
      p.text({
        message: 'Author name',
        placeholder: 'Jane Developer',
        initialValue: gitAuthor ?? '',
        validate: (value) => (value ? undefined : 'Required'),
      }),
  })
  if (p.isCancel(authorName)) return authorName as symbol

  const validateEmail = (value: string | undefined): string | undefined =>
    value && /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value) ? undefined : 'Enter a valid email'
  const gitEmail = flags.authorEmail === undefined ? await gitConfigValue('user.email') : undefined
  const authorEmail = await resolveField({
    flag: '--author-email',
    flagValue: flags.authorEmail,
    fallback: gitEmail,
    yes: flags.yes,
    validate: validateEmail,
    prompt: () =>
      p.text({
        message: 'Author email',
        placeholder: 'jane@example.com',
        initialValue: gitEmail ?? '',
        validate: validateEmail,
      }),
  })
  if (p.isCancel(authorEmail)) return authorEmail as symbol

  const validateLicense = (value: string | undefined): string | undefined =>
    value && (LICENSES as readonly string[]).includes(value)
      ? undefined
      : `Must be one of: ${LICENSES.join(', ')}`
  const license = await resolveField({
    flag: '--license',
    flagValue: flags.license,
    fallback: 'MIT',
    yes: flags.yes,
    validate: validateLicense,
    prompt: () =>
      p.select({
        message: 'License',
        options: LICENSES.map((value) => ({ value: value as string, label: value })),
        initialValue: 'MIT',
      }),
  })
  if (p.isCancel(license)) return license as symbol

  // The `--no-dashboard` flag pre-answers this; --yes accepts the default.
  const includeDashboard =
    flags.dashboard === false
      ? false
      : flags.yes || (await promptConfirm('Include dashboard plugin?', true))
  if (p.isCancel(includeDashboard)) return includeDashboard as symbol

  // The engine half is not yet generated by the CLI — the Rails templates
  // land in a follow-up PR. For now, we always answer false and note it.
  // Once the engine templates exist, restore the prompt:
  //
  //   const includeEngine = flags.engine === false
  //     ? false
  //     : await promptConfirm('Include Rails engine (API endpoints)?', true)
  const includeEngine = false
  if (flags.engine !== false) {
    p.log.warn(
      'Rails engine generation is coming in a future release. For now, scaffold the dashboard half here and use `spree-extension create` for the Ruby side.',
    )
  }

  if (!includeDashboard && !includeEngine) {
    p.cancel('Nothing to scaffold (dashboard half declined).')
    process.exit(1)
  }

  return {
    name: name as string,
    rubyName: rubyName as string,
    moduleName: moduleName as string,
    npmScope: (npmScope as string).trim(),
    authorName: authorName as string,
    authorEmail: authorEmail as string,
    license: license as string,
    includeDashboard: includeDashboard as boolean,
    includeEngine: includeEngine as boolean,
  }
}

async function promptConfirm(message: string, initial: boolean): Promise<boolean | symbol> {
  const result = await p.confirm({ message, initialValue: initial })
  return result
}

interface FieldSpec {
  /** Flag name for error messages, e.g. `--author`. */
  flag: string
  /** Value supplied via the flag, if any. Wins over everything; validated. */
  flagValue: string | undefined
  /** Default used by --yes and prefilled into the interactive prompt. */
  fallback: string | undefined
  /** True when running with --yes (accept fallback instead of prompting). */
  yes: boolean
  validate: (value: string | undefined) => string | undefined
  prompt: () => Promise<string | symbol>
}

/**
 * Resolve one scaffold answer from, in order: an explicit flag, the --yes
 * default, or an interactive prompt. Invalid flag values and --yes runs with
 * no usable default exit with a usage error rather than falling back to a
 * prompt — non-interactive means non-interactive.
 */
async function resolveField(spec: FieldSpec): Promise<string | symbol> {
  if (spec.flagValue !== undefined) {
    const problem = spec.validate(spec.flagValue)
    if (problem) {
      p.log.error(`Invalid value for ${pc.cyan(spec.flag)}: ${problem}`)
      process.exit(2)
    }
    return spec.flagValue
  }

  if (spec.yes) {
    const problem = spec.validate(spec.fallback)
    if (spec.fallback === undefined || problem) {
      p.log.error(
        `--yes could not resolve a default for ${pc.cyan(spec.flag)}` +
          (problem ? ` (${problem})` : '') +
          ` — pass ${pc.cyan(spec.flag)} explicitly.`,
      )
      process.exit(2)
    }
    return spec.fallback
  }

  return spec.prompt()
}

/** Read a git config value, returning undefined when unset or git is absent. */
async function gitConfigValue(key: string): Promise<string | undefined> {
  try {
    const { stdout } = await execaCommand(`git config --get ${key}`)
    const value = stdout.trim()
    return value || undefined
  } catch {
    return undefined
  }
}

// ---------------------------------------------------------------------------
// Template variable + skip-predicate builders
// ---------------------------------------------------------------------------

function buildVars(a: Answers): TemplateVars {
  const npmPackageName = a.npmScope ? `${a.npmScope}/${a.name}` : a.name
  return {
    name: a.name,
    plugin_name: a.name,
    ruby_name: a.rubyName,
    module_name: a.moduleName,
    npm_scope: a.npmScope,
    npm_package_name: npmPackageName,
    npm_dashboard_package: a.npmScope ? `${a.npmScope}/${a.name}-dashboard` : `${a.name}-dashboard`,
    author_name: a.authorName,
    author_email: a.authorEmail,
    license: a.license,
    year: String(new Date().getFullYear()),
  }
}

function buildSkipPredicate(a: Answers): (relPath: string) => boolean {
  const skipDashboard = !a.includeDashboard
  const skipEngine = !a.includeEngine
  return (rel) => {
    if (skipDashboard && (rel === 'packages/dashboard' || rel.startsWith('packages/dashboard/'))) {
      return true
    }
    if (skipEngine && (rel === 'engine' || rel.startsWith('engine/'))) return true
    return false
  }
}

// ---------------------------------------------------------------------------
// Post-scaffold install + banner
// ---------------------------------------------------------------------------

async function runInstall(dst: string, answers: Answers): Promise<void> {
  const s = p.spinner()
  if (answers.includeDashboard) {
    s.start('Running pnpm install...')
    try {
      await execaCommand('pnpm install', { cwd: dst, stdio: 'pipe' })
      s.stop('pnpm install complete.')
    } catch (err) {
      s.stop(pc.yellow('pnpm install failed — run it manually.'))
      p.log.warn(err instanceof Error ? err.message : String(err))
    }
  }
  if (answers.includeEngine) {
    s.start('Running bundle install in engine/...')
    try {
      await execaCommand('bundle install', { cwd: path.join(dst, 'engine'), stdio: 'pipe' })
      s.stop('bundle install complete.')
    } catch (err) {
      s.stop(pc.yellow('bundle install failed — run it manually.'))
      p.log.warn(err instanceof Error ? err.message : String(err))
    }
  }
}

function printNextSteps(answers: Answers, dst: string, installed: boolean): void {
  const lines: string[] = ['']
  lines.push(pc.bold('Next steps'))
  lines.push(`  ${pc.dim('cd')} ${path.relative(process.cwd(), dst) || '.'}`)
  if (!installed) {
    if (answers.includeDashboard) lines.push(`  ${pc.dim('pnpm')} install`)
    if (answers.includeEngine)
      lines.push(`  ${pc.dim('cd engine && bundle')} install && ${pc.dim('cd ..')}`)
  }
  if (answers.includeDashboard) {
    lines.push('')
    lines.push(pc.bold('Dashboard plugin'))
    lines.push(
      `  Edit ${pc.cyan('packages/dashboard/src/index.tsx')} to wire your nav/route/slot extensions.`,
    )
    lines.push(
      `  See ${pc.cyan('https://spreecommerce.org/docs/developer/dashboard/plugins/overview')}`,
    )
  }
  if (answers.includeEngine) {
    lines.push('')
    lines.push(pc.bold('Rails engine'))
    lines.push(
      `  Edit ${pc.cyan(`engine/app/controllers/spree/api/v3/admin/${answers.rubyName}_controller.rb`)}`,
    )
    lines.push(
      `  See ${pc.cyan('https://spreecommerce.org/docs/developer/contributing/creating-an-extension')}`,
    )
  }
  lines.push('')
  p.note(lines.join('\n'), 'Your plugin is scaffolded.')
}

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

function pascalCase(input: string): string {
  return input
    .split(/[_-]/)
    .filter(Boolean)
    .map((part) => part[0].toUpperCase() + part.slice(1))
    .join('')
}

/**
 * The bundled template lives next to the CLI's dist/ in the published
 * tarball (`dist/templates/plugin/`) and next to source in dev
 * (`packages/cli/templates/plugin/`). Resolve relative to this file so
 * both layouts work.
 */
function resolveTemplatePath(): string {
  const here = path.dirname(fileURLToPath(import.meta.url))
  // dev: src/commands/plugin.ts → templates/plugin/ via ../../templates/plugin
  // built: dist/index.js → dist/templates/plugin/ (tsup copies templates into
  // dist/ on build; the tarball only ships dist/)
  const candidates = [
    path.resolve(here, TEMPLATE_RELATIVE_PATH),
    path.resolve(here, 'templates/plugin'),
  ]
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) return candidate
  }
  throw new Error(
    `Plugin template not found. Looked in:\n  ${candidates.join('\n  ')}\n\nReinstall @spree/cli to fix.`,
  )
}
