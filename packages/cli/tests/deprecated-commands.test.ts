import * as p from '@clack/prompts'
import { Command } from 'commander'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { addUncataloguedExtension } from '../src/commands/add'
import { registerBundleCommand } from '../src/commands/bundle'
import { ejectProject } from '../src/commands/eject'
import { registerGenerateCommand } from '../src/commands/generate'
import { registerRailsCommand } from '../src/commands/rails'
import { registerRakeCommand } from '../src/commands/rake'
import { registerRoutesCommand } from '../src/commands/routes'
import { runsFromSource } from '../src/context'
import { dockerComposeExecOrRun } from '../src/docker'

vi.mock('../src/context', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/context')>()),
  detectProject: () => ({ mode: 'docker', projectDir: '/proj', port: 3000 }),
  runsFromSource: vi.fn(() => true),
}))

vi.mock('@clack/prompts', () => ({
  cancel: vi.fn(),
  confirm: vi.fn(),
  isCancel: () => false,
  intro: vi.fn(),
  outro: vi.fn(),
}))

vi.mock('../src/commands/eject', () => ({ ejectProject: vi.fn(async () => undefined) }))
vi.mock('../src/commands/add', () => ({
  addUncataloguedExtension: vi.fn(async () => undefined),
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
      ['bundle', 'add', '--version', '~> 6.0', 'spree_stripe'],
      ['bundle', 'add', '--version', '~> 6.0', 'spree_stripe'],
      'spree exec bundle add --version ~> 6.0 spree_stripe',
    ],
    [['bundle', 'outdated'], ['bundle', 'outdated'], 'spree exec bundle outdated'],
    [
      ['bundle', 'remove', 'spree_foo'],
      ['bundle', 'remove', 'spree_foo'],
      'spree exec bundle remove',
    ],
    [['routes'], ['bin/rails', 'routes'], 'spree api endpoints'],
    [
      ['routes', '-g', 'products'],
      ['bin/rails', 'routes', '-g', 'products'],
      'spree exec bin/rails routes -g products',
    ],
    [
      ['bundle', 'add', 'spree_stripe', '--version', '6.0'],
      ['bundle', 'add', 'spree_stripe', '--version', '6.0'],
      'spree exec bundle add spree_stripe --version 6.0',
    ],
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

  it.each([
    [
      ['generate', 'api_resource', 'Brand', 'name:string'],
      ['spree:api_resource', 'Brand', 'name:string'],
    ],
    [
      ['g', 'model_decorator', 'Product'],
      ['spree:model_decorator', 'Product'],
    ],
    [
      ['generate', 'migration', 'AddX'],
      ['migration', 'AddX'],
    ],
    [['generate', 'spree:install'], ['spree:install']],
    [['generate', 'spree_stripe:install'], ['spree_stripe:install']],
  ])('spree %j runs without a notice', async (argv, generatorArgs) => {
    await run(argv)

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bin/rails', 'generate', ...generatorArgs],
      '/proj',
    )
    expect(stderr).not.toHaveBeenCalled()
    expect(ejectProject).not.toHaveBeenCalled()
  })
})

describe('spree bundle on a project', () => {
  let stderr: ReturnType<typeof vi.spyOn>

  beforeEach(() => {
    vi.clearAllMocks()
    stderr = vi.spyOn(console, 'error').mockImplementation(() => {})
    vi.spyOn(process, 'exit').mockImplementation((code?: number | string | null) => {
      throw new Error(`process.exit(${code})`)
    })
  })

  afterEach(() => {
    vi.mocked(runsFromSource).mockReturnValue(true)
    vi.restoreAllMocks()
  })

  // Only an exact gem name is a catalogued extension: `stripe` is the Stripe
  // gem, not the `stripe` extension.
  it.each([
    ['spree_stripe', 'spree add stripe'],
    ['spree_paypal_checkout', 'spree add paypal'],
    ['stripe', 'spree add --gem stripe'],
    ['spree_foo', 'spree add --gem spree_foo'],
  ])('installs %s through spree add', async (gem, replacement) => {
    await run(['bundle', 'add', gem])

    expect(addUncataloguedExtension).toHaveBeenCalledWith(gem, undefined, {
      yes: false,
      retry: `${replacement} --yes`,
    })
    expect(dockerComposeExecOrRun).not.toHaveBeenCalled()
    expect(stderr).toHaveBeenCalledWith(expect.stringContaining(replacement))
  })

  it('refuses to change the bundle of a project on the prebuilt image', async () => {
    vi.mocked(runsFromSource).mockReturnValue(false)

    await expect(run(['bundle', 'remove', 'spree_foo'])).rejects.toThrow('process.exit(1)')

    expect(dockerComposeExecOrRun).not.toHaveBeenCalled()
    expect(p.cancel).toHaveBeenCalledWith(expect.stringContaining('spree add <extension>'))
  })

  it('still reads the bundle of a project on the prebuilt image', async () => {
    vi.mocked(runsFromSource).mockReturnValue(false)

    await run(['bundle', 'outdated'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bundle', 'outdated'],
      '/proj',
      expect.any(Object),
    )
  })
})

describe('spree generate on a project on the prebuilt image', () => {
  const originalIsTTY = process.stdin.isTTY

  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(runsFromSource).mockReturnValue(false)
    vi.spyOn(process, 'exit').mockImplementation((code?: number | string | null) => {
      throw new Error(`process.exit(${code})`)
    })
  })

  afterEach(() => {
    vi.mocked(runsFromSource).mockReturnValue(true)
    Object.defineProperty(process.stdin, 'isTTY', { value: originalIsTTY, configurable: true })
    vi.restoreAllMocks()
  })

  it('stops with no terminal to ask in, naming the command that agrees', async () => {
    Object.defineProperty(process.stdin, 'isTTY', { value: false, configurable: true })

    await expect(run(['generate', 'api_resource', 'Brand', "title:string{it's}"])).rejects.toThrow(
      'process.exit(1)',
    )

    expect(ejectProject).not.toHaveBeenCalled()
    expect(dockerComposeExecOrRun).not.toHaveBeenCalled()
    const message = vi.mocked(p.cancel).mock.calls[0][0]
    expect(message).toContain('ask them first')
    expect(message).toContain(`spree generate --yes api_resource Brand 'title:string{it'\\''s}'`)
  })

  it('ejects and then generates once the developer agrees', async () => {
    Object.defineProperty(process.stdin, 'isTTY', { value: true, configurable: true })
    vi.mocked(p.confirm).mockResolvedValue(true)

    await run(['generate', 'model_decorator', 'Product'])

    expect(ejectProject).toHaveBeenCalledWith('/proj')
    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bin/rails', 'generate', 'spree:model_decorator', 'Product'],
      '/proj',
    )
  })

  it('ejects without asking with --yes before the generator name', async () => {
    Object.defineProperty(process.stdin, 'isTTY', { value: false, configurable: true })

    await run(['generate', '--yes', 'migration', 'AddX', '--force'])

    expect(p.confirm).not.toHaveBeenCalled()
    expect(ejectProject).toHaveBeenCalledWith('/proj')
    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bin/rails', 'generate', 'migration', 'AddX', '--force'],
      '/proj',
    )
  })

  it("shows a generator's help without ejecting", async () => {
    Object.defineProperty(process.stdin, 'isTTY', { value: false, configurable: true })

    await run(['generate', 'model', '--help'])

    expect(ejectProject).not.toHaveBeenCalled()
    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bin/rails', 'generate', 'spree:model', '--help'],
      '/proj',
    )
  })

  it('stops without ejecting when the developer declines', async () => {
    Object.defineProperty(process.stdin, 'isTTY', { value: true, configurable: true })
    vi.mocked(p.confirm).mockResolvedValue(false)

    await expect(run(['generate', 'model_decorator', 'Product'])).rejects.toThrow('process.exit(0)')
    expect(ejectProject).not.toHaveBeenCalled()
    expect(dockerComposeExecOrRun).not.toHaveBeenCalled()
  })
})
