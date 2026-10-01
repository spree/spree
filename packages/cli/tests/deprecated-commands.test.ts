import { Command } from 'commander'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { registerBundleCommand } from '../src/commands/bundle'
import { registerGenerateCommand } from '../src/commands/generate'
import { registerRailsCommand } from '../src/commands/rails'
import { registerRakeCommand } from '../src/commands/rake'
import { registerRoutesCommand } from '../src/commands/routes'
import { dockerComposeExecOrRun } from '../src/docker'

vi.mock('../src/context', () => ({
  detectProject: () => ({ mode: 'docker', projectDir: '/proj', port: 3000 }),
}))

vi.mock('../src/docker', () => ({
  dockerComposeExecOrRun: vi.fn().mockResolvedValue(undefined),
}))

async function run(argv: string[]): Promise<void> {
  const program = new Command().enablePositionalOptions()
  for (const register of [
    registerBundleCommand,
    registerGenerateCommand,
    registerRailsCommand,
    registerRakeCommand,
    registerRoutesCommand,
  ]) {
    register(program)
  }
  await program.parseAsync(argv, { from: 'user' })
}

// Rails-named commands keep their 6.x behaviour and name their replacement
// (docs/plans/6.0-backend-agnostic-cli.md).
describe('deprecated Rails-named commands', () => {
  let stderr: ReturnType<typeof vi.spyOn>

  beforeEach(() => {
    vi.clearAllMocks()
    stderr = vi.spyOn(console, 'error').mockImplementation(() => {})
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  it.each([
    [
      ['rails', 'runner', 'puts 1'],
      ['bin/rails', 'runner', 'puts 1'],
      'spree exec bin/rails runner',
    ],
    [
      ['rake', 'spree:search:reindex'],
      ['bin/rake', 'spree:search:reindex'],
      'spree task search:reindex',
    ],
    [
      ['rake', 'db:rollback', 'STEP=2'],
      ['bin/rake', 'db:rollback', 'STEP=2'],
      'spree exec bin/rake',
    ],
    [
      ['bundle', 'add', 'spree_stripe'],
      ['bundle', 'add', 'spree_stripe'],
      'spree add spree_stripe',
    ],
    [['bundle', 'outdated'], ['bundle', 'outdated'], 'spree exec bundle outdated'],
    [['routes'], ['bin/rails', 'routes'], 'spree api endpoints'],
  ])('spree %j still runs and points at the replacement', async (argv, inner, replacement) => {
    await run(argv)

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      inner,
      '/proj',
      ...(argv[0] === 'bundle' ? [expect.any(Object)] : []),
    )
    expect(stderr).toHaveBeenCalledWith(expect.stringContaining(replacement))
  })
})

describe('spree generate', () => {
  let stderr: ReturnType<typeof vi.spyOn>

  beforeEach(() => {
    vi.clearAllMocks()
    stderr = vi.spyOn(console, 'error').mockImplementation(() => {})
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('runs api_resource without a notice', async () => {
    await run(['generate', 'api_resource', 'Brand', 'name:string'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bin/rails', 'generate', 'spree:api_resource', 'Brand', 'name:string'],
      '/proj',
    )
    expect(stderr).not.toHaveBeenCalled()
  })

  it('still runs other Spree generators, pointing at spree exec', async () => {
    await run(['g', 'model_decorator', 'Product'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bin/rails', 'generate', 'spree:model_decorator', 'Product'],
      '/proj',
    )
    expect(stderr).toHaveBeenCalledWith(
      expect.stringContaining('spree exec bin/rails generate spree:model_decorator Product'),
    )
  })

  it('forwards Rails built-ins unprefixed', async () => {
    await run(['generate', 'migration', 'AddX'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bin/rails', 'generate', 'migration', 'AddX'],
      '/proj',
    )
  })

  it('points extension installers at spree add', async () => {
    await run(['generate', 'spree_stripe:install'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bin/rails', 'generate', 'spree_stripe:install'],
      '/proj',
    )
    expect(stderr).toHaveBeenCalledWith(expect.stringContaining('spree add spree_stripe'))
  })
})
