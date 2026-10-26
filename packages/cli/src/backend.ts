// The only place the CLI speaks Rails. Commands say what they want (a console,
// a task, a migration) and this module says how the backend does it, so
// changing the backend means changing this file rather than every command.
// See docs/plans/6.0-backend-agnostic-cli.md.

/** A task by its full backend name, e.g. `db:seed` or `spree:cli:create_admin`. */
export function backendTaskCommand(task: string, args: string[] = []): string[] {
  return railsCommand([task, ...args])
}

/** A Spree maintenance task, named without its `spree:` namespace (`search:reindex`). */
export function spreeTask(name: string): string {
  return `spree:${name}`
}

export function taskCommand(name: string, args: string[] = []): string[] {
  return backendTaskCommand(spreeTask(name), args)
}

export const CONSOLE = railsCommand(['console'])

export const SEED_TASK = 'db:seed'

export const MIGRATE = railsCommand([spreeTask('install:migrations'), 'db:migrate'])

export const MIGRATE_STATUS = backendTaskCommand('db:migrate:status')

export const DATABASE_RESET = railsCommand([
  'db:drop',
  'db:create',
  spreeTask('install:migrations'),
  'db:migrate',
  SEED_TASK,
])

export const UPGRADE = taskCommand('upgrade')

export const PREPARE_DATABASE = backendTaskCommand('db:prepare')

export const TEST_ENV = { RAILS_ENV: 'test' }

// Creates the test database first, so the suite runs on a fresh project; the
// test helper loads the schema into it. Not `db:prepare`, which would seed a
// newly created database. A create failure is left for the runner to report.
export function testCommand(args: string[]): string[] {
  return [
    'sh',
    '-c',
    'bin/rails db:create >/dev/null 2>&1; exec bundle exec rspec "$@"',
    'spree test',
    ...args,
  ]
}

export function rollbackCommand(steps?: number, args: string[] = []): string[] {
  return backendTaskCommand('db:rollback', [...(steps ? [`STEP=${steps}`] : []), ...args])
}

export function addPackageCommand(name: string): string[] {
  return bundleCommand(['add', name])
}

export function updatePackagesCommand(names: string[]): string[] {
  return bundleCommand(['update', ...names])
}

export const LIST_PACKAGES = bundleCommand(['list', '--name-only'])

export const INSTALL_PACKAGES = bundleCommand(['install'])

export const LIST_GENERATORS = railsCommand(['generate', '--help'])

/** The install generator an extension ships, e.g. `spree_stripe:install`. */
export function extensionInstallGenerator(name: string): string {
  return `${name}:install`
}

export function runGeneratorCommand(generator: string, args: string[] = []): string[] {
  return railsCommand(['generate', generator, ...args])
}

// The raw tools, used directly only by the deprecated pass-through commands
// (`spree rails`, `spree rake`, `spree bundle`, `spree routes`).

export function railsCommand(args: string[]): string[] {
  return ['bin/rails', ...args]
}

export function rakeCommand(args: string[]): string[] {
  return ['bin/rake', ...args]
}

export function bundleCommand(args: string[]): string[] {
  return ['bundle', ...args]
}

export function routesCommand(args: string[]): string[] {
  return railsCommand(['routes', ...args])
}
