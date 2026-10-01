// The only place the CLI speaks Rails. Commands say what they want (a console,
// a task, a migration) and this module says how the current backend does it,
// so the Spree 7 Node backend replaces this file rather than every command.
// See docs/plans/6.0-backend-agnostic-cli.md.

export const CONSOLE = ['bin/rails', 'console']

export const SEED_TASK = 'db:seed'

export const MIGRATE = ['bin/rails', 'spree:install:migrations', 'db:migrate']

export const MIGRATE_STATUS = ['bin/rails', 'db:migrate:status']

export const DATABASE_RESET = [
  'bin/rails',
  'db:drop',
  'db:create',
  'spree:install:migrations',
  'db:migrate',
  'db:seed',
]

export const UPGRADE = ['bin/rails', 'spree:upgrade']

export const PREPARE_DATABASE = ['bin/rails', 'db:prepare']

export const TEST_ENV = { RAILS_ENV: 'test' }

export const SUPPORTED_GENERATORS = ['api_resource']

/** A Spree maintenance task, named without its `spree:` namespace (`search:reindex`). */
export function spreeTask(name: string): string {
  return `spree:${name}`
}

export function taskCommand(name: string, args: string[] = []): string[] {
  return backendTaskCommand(spreeTask(name), args)
}

/** A task by its full backend name, e.g. `db:seed` or `spree:cli:create_admin`. */
export function backendTaskCommand(task: string, args: string[] = []): string[] {
  return ['bin/rails', task, ...args]
}

export function testCommand(args: string[]): string[] {
  return ['bundle', 'exec', 'rspec', ...args]
}

export function rollbackCommand(steps?: number, args: string[] = []): string[] {
  return ['bin/rails', 'db:rollback', ...(steps ? [`STEP=${steps}`] : []), ...args]
}

export function addPackageCommand(name: string): string[] {
  return ['bundle', 'add', name]
}

export function updatePackagesCommand(names: string[]): string[] {
  return ['bundle', 'update', ...names]
}

export const LIST_PACKAGES = ['bundle', 'list', '--name-only']

export const LIST_GENERATORS = ['bin/rails', 'generate', '--help']

/** The install generator an extension ships, e.g. `spree_stripe:install`. */
export function extensionInstallGenerator(name: string): string {
  return `${name}:install`
}

export function runGeneratorCommand(generator: string, args: string[] = []): string[] {
  return ['bin/rails', 'generate', generator, ...args]
}
