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
}

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
  const name =
    nameArg ??
    (await p.text({
      message: 'Plugin name',
      placeholder: 'brands',
      validate: (value) => {
        if (!value) return 'Required'
        if (!/^[a-z][a-z0-9-]*$/.test(value)) {
          return 'Use lowercase letters, digits, and dashes (e.g. "brands" or "loyalty-points")'
        }
        return undefined
      },
    }))
  if (p.isCancel(name)) return name as symbol

  const rubyDefault = `spree_${(name as string).replace(/-/g, '_')}`
  const rubyName = await p.text({
    message: 'Ruby gem name',
    placeholder: rubyDefault,
    initialValue: rubyDefault,
    validate: (value) =>
      value && /^[a-z][a-z0-9_]*$/.test(value)
        ? undefined
        : 'Use lowercase letters, digits, and underscores (e.g. "spree_brands")',
  })
  if (p.isCancel(rubyName)) return rubyName as symbol

  const moduleDefault = pascalCase(rubyName as string)
  const moduleName = await p.text({
    message: 'Ruby module / TS namespace',
    placeholder: moduleDefault,
    initialValue: moduleDefault,
    validate: (value) =>
      value && /^[A-Z][A-Za-z0-9]*$/.test(value) ? undefined : 'PascalCase (e.g. "SpreeBrands")',
  })
  if (p.isCancel(moduleName)) return moduleName as symbol

  const npmScope = await p.text({
    message: 'npm scope (optional, leave blank for unscoped)',
    placeholder: '@my-org',
    initialValue: '',
    validate: (value) =>
      !value || /^@[a-z0-9][a-z0-9-]*$/.test(value)
        ? undefined
        : 'Must start with @ and contain lowercase letters/digits/dashes',
  })
  if (p.isCancel(npmScope)) return npmScope as symbol

  const authorName = await p.text({
    message: 'Author name',
    placeholder: 'Jane Developer',
    validate: (value) => (value ? undefined : 'Required'),
  })
  if (p.isCancel(authorName)) return authorName as symbol

  const authorEmail = await p.text({
    message: 'Author email',
    placeholder: 'jane@example.com',
    validate: (value) =>
      value && /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value) ? undefined : 'Enter a valid email',
  })
  if (p.isCancel(authorEmail)) return authorEmail as symbol

  const license = await p.select({
    message: 'License',
    options: [
      { value: 'MIT', label: 'MIT' },
      { value: 'Apache-2.0', label: 'Apache-2.0' },
      { value: 'BSD-3-Clause', label: 'BSD-3-Clause' },
    ],
    initialValue: 'MIT',
  })
  if (p.isCancel(license)) return license as symbol

  // The `--no-dashboard` flag pre-answers this; otherwise prompt.
  const includeDashboard =
    flags.dashboard === false ? false : await prompt_confirm('Include dashboard plugin?', true)
  if (p.isCancel(includeDashboard)) return includeDashboard as symbol

  // The engine half is not yet generated by the CLI — the Rails templates
  // land in a follow-up PR. For now, we always answer false and note it.
  // Once the engine templates exist, restore the prompt:
  //
  //   const includeEngine = flags.engine === false
  //     ? false
  //     : await prompt_confirm('Include Rails engine (API endpoints)?', true)
  const includeEngine = false
  if (flags.engine !== false) {
    p.log.warn(
      'Rails engine generation is coming in a future release. For now, scaffold the dashboard half here and use `spree-extension create` for the Ruby side.',
    )
  }

  if (!includeDashboard && !includeEngine) {
    p.log.error('Nothing to scaffold (dashboard half declined).')
    return Symbol('cancel') as symbol
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

async function prompt_confirm(message: string, initial: boolean): Promise<boolean | symbol> {
  const result = await p.confirm({ message, initialValue: initial })
  return result
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
      `  See ${pc.cyan('https://docs.spreecommerce.org/developer/customization/dashboard-plugins')}`,
    )
  }
  if (answers.includeEngine) {
    lines.push('')
    lines.push(pc.bold('Rails engine'))
    lines.push(
      `  Edit ${pc.cyan(`engine/app/controllers/spree/api/v3/admin/${answers.rubyName}_controller.rb`)}`,
    )
    lines.push(
      `  See ${pc.cyan('https://docs.spreecommerce.org/developer/customization/extensions')}`,
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
  // built: dist/index.js → templates/plugin/ via ../templates/plugin
  const candidates = [
    path.resolve(here, TEMPLATE_RELATIVE_PATH),
    path.resolve(here, '../templates/plugin'),
  ]
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) return candidate
  }
  throw new Error(
    `Plugin template not found. Looked in:\n  ${candidates.join('\n  ')}\n\nReinstall @spree/cli to fix.`,
  )
}
