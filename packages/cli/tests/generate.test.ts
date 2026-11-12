import { Command } from 'commander'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { registerGenerateCommand } from '../src/commands/generate'
import {
  type DockerComposeStreamOptions,
  dockerComposeExecOrRun,
  dockerComposeStream,
} from '../src/docker'
import {
  formatGeneratorSummary,
  GeneratorOutput,
  nextSteps,
  parseGeneratorOutput,
} from '../src/lib/generator-output'

vi.mock('picocolors', async (importOriginal) => {
  const pc = (await importOriginal<{ default: typeof import('picocolors') }>()).default
  return { default: pc.createColors(false) }
})

vi.mock('../src/context', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/context')>()),
  detectProject: () => ({ mode: 'docker', projectDir: '/proj', port: 3000 }),
  runsFromSource: () => true,
}))

vi.mock('../src/docker', () => ({
  dockerComposeExecOrRun: vi.fn().mockResolvedValue(undefined),
  dockerComposeStream: vi.fn().mockResolvedValue(undefined),
}))

const SUBSCRIBER_OUTPUT = `[Spree Events] Registered 12 subscribers
      create  app/subscribers/oms_order_sync_subscriber.rb
      insert  config/initializers/spree.rb
      create  spec/subscribers/oms_order_sync_subscriber_spec.rb
`

describe('parseGeneratorOutput', () => {
  it('keeps the actions and drops progress lines and boot noise', () => {
    const output = `${SUBSCRIBER_OUTPUT}      invoke  active_record
       exist    app/models
   identical  config/initializers/spree.rb (OmsOrderSyncSubscriber already registered)
        skip  routes.rb (admin: namespace block not found — add manually)
        note  no events given — edit \`subscribes_to\`
`
    expect(parseGeneratorOutput(output)).toEqual({
      actions: [
        { verb: 'created', target: 'app/subscribers/oms_order_sync_subscriber.rb' },
        { verb: 'changed', target: 'config/initializers/spree.rb' },
        { verb: 'created', target: 'spec/subscribers/oms_order_sync_subscriber_spec.rb' },
        {
          verb: 'unchanged',
          target: 'config/initializers/spree.rb (OmsOrderSyncSubscriber already registered)',
        },
        { verb: 'skipped', target: 'routes.rb (admin: namespace block not found — add manually)' },
        { verb: 'note', target: 'no events given — edit `subscribes_to`' },
      ],
      messages: [],
    })
  })

  it("reads a nested generator's deeper-indented actions", () => {
    const output =
      '      invoke  active_record\n      create    db/migrate/20260101_create_spree_brands.rb\n'
    expect(parseGeneratorOutput(output).actions).toEqual([
      { verb: 'created', target: 'db/migrate/20260101_create_spree_brands.rb' },
    ])
  })

  it("keeps the generator's own messages and strips colour codes", () => {
    const output =
      '\u001b[1m\u001b[32m      create\u001b[0m  app/models/spree/brand.rb\n\n✓ Generated Spree::Brand API resource\n\n  Next steps:\n    1. Apply the migration:  pnpm exec spree migrate\n\n'
    expect(parseGeneratorOutput(output)).toEqual({
      actions: [{ verb: 'created', target: 'app/models/spree/brand.rb' }],
      messages: [
        '✓ Generated Spree::Brand API resource',
        '',
        '  Next steps:',
        '    1. Apply the migration:  pnpm exec spree migrate',
      ],
    })
  })

  it('does not take indented prose for an action', () => {
    expect(parseGeneratorOutput('  usage  is wrong\n').actions).toEqual([])
  })
})

describe('nextSteps', () => {
  it('restarts for an initializer, migrates for a migration and tests new specs', () => {
    const result = parseGeneratorOutput(
      `${SUBSCRIBER_OUTPUT}      create  db/migrate/20260101_create_spree_brands.rb\n`,
    )
    expect(nextSteps(result)).toEqual([
      { command: 'spree restart', reason: 'config/initializers/spree.rb loads only at boot' },
      { command: 'spree migrate' },
      { command: 'spree test spec/subscribers/oms_order_sync_subscriber_spec.rb' },
    ])
  })

  it('leaves out a step the generator already names', () => {
    const result = parseGeneratorOutput(
      '      create  db/migrate/20260101_create_spree_brands.rb\n  2. Apply the migration:  pnpm exec spree migrate\n',
    )
    expect(nextSteps(result)).toEqual([])
  })

  it('suggests nothing when nothing changed', () => {
    const result = parseGeneratorOutput(
      '   identical  config/initializers/spree.rb (OmsOrderSyncSubscriber already registered)\n',
    )
    expect(nextSteps(result)).toEqual([])
  })
})

describe('formatGeneratorSummary', () => {
  it('lists the files and the next steps', () => {
    expect(
      formatGeneratorSummary('spree:subscriber', parseGeneratorOutput(SUBSCRIBER_OUTPUT)),
    ).toBe(`spree:subscriber finished:
  created  app/subscribers/oms_order_sync_subscriber.rb
  changed  config/initializers/spree.rb
  created  spec/subscribers/oms_order_sync_subscriber_spec.rb

Next:
  spree restart  # config/initializers/spree.rb loads only at boot
  spree test spec/subscribers/oms_order_sync_subscriber_spec.rb`)
  })

  it('says so when the generator touched nothing, and shows what it printed', () => {
    expect(
      formatGeneratorSummary(
        'spree:foo',
        parseGeneratorOutput('Could not find generator "spree:foo".\n'),
      ),
    ).toBe(
      'spree:foo finished without creating or changing any files.\n\nCould not find generator "spree:foo".',
    )
  })
})

describe('GeneratorOutput', () => {
  it('joins lines split across chunks and keeps stderr out of the summary', () => {
    const output = new GeneratorOutput()
    output.write('      create  app/mod', 'stdout')
    output.write('DEPRECATION WARNING: something\n', 'stderr')
    output.write('els/spree/brand.rb\n', 'stdout')

    expect(output.result().actions).toEqual([
      { verb: 'created', target: 'app/models/spree/brand.rb' },
    ])
  })

  it('hands over a pending prompt once, so the answer starts a fresh line', () => {
    const output = new GeneratorOutput()
    output.write(
      '    conflict  app/models/spree/brand.rb\nOverwrite app/models/spree/brand.rb? [Ynaqdh] ',
      'stdout',
    )

    expect(output.hasPartialLine()).toBe(true)
    expect(output.takePrompt()).toBe('Overwrite app/models/spree/brand.rb? [Ynaqdh] ')
    expect(output.hasPartialLine()).toBe(false)

    output.write('       force  app/models/spree/brand.rb\n', 'stdout')
    expect(output.result().actions).toEqual([
      { verb: 'conflict', target: 'app/models/spree/brand.rb' },
      { verb: 'changed', target: 'app/models/spree/brand.rb' },
    ])
  })
})

describe('nextSteps quoting', () => {
  it('quotes a spec path a shell would expand', () => {
    const steps = nextSteps(
      parseGeneratorOutput('      create  spec/models/$(touch_pwned)_spec.rb\n'),
    )

    expect(steps.map((step) => step.command)).toEqual([
      "spree test 'spec/models/$(touch_pwned)_spec.rb'",
    ])
  })

  it('leaves ordinary spec paths as they are', () => {
    const steps = nextSteps(parseGeneratorOutput('      create  spec/models/spree/brand_spec.rb\n'))

    expect(steps.map((step) => step.command)).toEqual([
      'spree test spec/models/spree/brand_spec.rb',
    ])
  })
})

describe('GeneratorOutput with delayed chunks', () => {
  it('keeps an action line whole when part of it was shown before the rest arrived', () => {
    const output = new GeneratorOutput()
    output.write('Generating', 'stdout')
    output.takePrompt()
    output.write(' brand\n      create  db/mig', 'stdout')
    expect(output.hasPartialLine()).toBe(false)
    output.write('rate/20260101_create_brands.rb\n', 'stdout')

    const result = output.result()
    expect(result.actions).toEqual([
      { verb: 'created', target: 'db/migrate/20260101_create_brands.rb' },
    ])
    expect(nextSteps(result).map((step) => step.command)).toContain('spree migrate')
  })

  it('treats a bare carriage return as a line break', () => {
    const output = new GeneratorOutput()
    output.write('Loading\r      create  db/migrate/20260101_create_brands.rb\n', 'stdout')

    expect(output.result().actions).toEqual([
      { verb: 'created', target: 'db/migrate/20260101_create_brands.rb' },
    ])
  })

  it('keeps bracketed warnings and drops other boot lines', () => {
    const result = parseGeneratorOutput(
      '[Spree Events] subscribed\n[Spree WARNING] Missing migrations.\n      create  app/models/spree/brand.rb\n',
    )

    expect(result.messages).toEqual(['[Spree WARNING] Missing migrations.'])
  })
})

async function run(argv: string[]): Promise<void> {
  const program = new Command().enablePositionalOptions()
  registerGenerateCommand(program)
  await program.parseAsync(argv, { from: 'user' })
}

function streamOutput(chunks: [string, 'stdout' | 'stderr'][], error?: Error) {
  vi.mocked(dockerComposeStream).mockImplementation(
    async (_argv: string[], _dir: string, { onOutput }: DockerComposeStreamOptions) => {
      for (const [chunk, stream] of chunks) onOutput(chunk, stream)
      if (error) throw error
    },
  )
}

describe('spree generate output', () => {
  let stdout: string[]
  let stderr: string[]

  beforeEach(() => {
    vi.clearAllMocks()
    stdout = []
    stderr = []
    vi.spyOn(console, 'log').mockImplementation((line: string) => stdout.push(`${line}\n`))
    vi.spyOn(console, 'error').mockImplementation((line: string) => stderr.push(`${line}\n`))
    vi.spyOn(process.stdout, 'write').mockImplementation((chunk) => {
      stdout.push(String(chunk))
      return true
    })
    vi.spyOn(process.stderr, 'write').mockImplementation((chunk) => {
      stderr.push(String(chunk))
      return true
    })
    vi.spyOn(process, 'exit').mockImplementation((code?: number | string | null) => {
      throw new Error(`process.exit(${code})`)
    })
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('prints a summary instead of the generator and Docker output', async () => {
    streamOutput([
      ['web container is not running — using a one-off container\n', 'stderr'],
      [' Container proj-postgres-1  Running\n', 'stderr'],
      [SUBSCRIBER_OUTPUT, 'stdout'],
    ])

    await run(['generate', 'subscriber', 'OmsOrderSync', 'order.placed'])

    const printed = stdout.join('')
    expect(printed).toContain('created  app/subscribers/oms_order_sync_subscriber.rb')
    expect(printed).toContain('spree restart')
    expect(printed).not.toContain('[Spree Events]')
    expect(stderr.join('')).toBe('')
    expect(dockerComposeExecOrRun).not.toHaveBeenCalled()
  })

  it('prints the full output, untouched, with --verbose', async () => {
    await run(['generate', '--verbose', 'subscriber', 'OmsOrderSync'])

    expect(dockerComposeExecOrRun).toHaveBeenCalledWith(
      ['bin/rails', 'generate', 'spree:subscriber', 'OmsOrderSync'],
      '/proj',
    )
    expect(dockerComposeStream).not.toHaveBeenCalled()
  })

  it('passes --verbose after the generator name through to the generator', async () => {
    await run(['generate', 'model', 'Brand', '--verbose'])

    expect(dockerComposeStream).toHaveBeenCalledWith(
      ['bin/rails', 'generate', 'spree:model', 'Brand', '--verbose'],
      '/proj',
      expect.any(Object),
    )
  })

  it('prints everything the generator printed when it fails, and exits with its code', async () => {
    streamOutput(
      [
        [' Container proj-web-1  Started\n', 'stderr'],
        ['      create  app/models/spree/brand.rb\n', 'stdout'],
        ['NameError: uninitialized constant Spree::Brnd\n', 'stderr'],
      ],
      Object.assign(new Error('Command failed with exit code 1'), { exitCode: 1 }),
    )

    await expect(run(['generate', 'model', 'Brand'])).rejects.toThrow('process.exit(1)')

    expect(stdout.join('')).toBe('      create  app/models/spree/brand.rb\n')
    expect(stderr.join('')).toContain(' Container proj-web-1  Started\n')
    expect(stderr.join('')).toContain('NameError: uninitialized constant Spree::Brnd')
    expect(stderr.join('')).toContain('spree:model failed (exit code 1)')
  })

  it('rethrows an error that is not a failed generator, after showing the output', async () => {
    streamOutput([['partial output\n', 'stdout']], new Error('spawn docker ENOENT'))

    await expect(run(['generate', 'model', 'Brand'])).rejects.toThrow('spawn docker ENOENT')
    expect(stdout.join('')).toBe('partial output\n')
  })

  it('shows a prompt the generator is waiting on', async () => {
    vi.mocked(dockerComposeStream).mockImplementation(
      async (_argv: string[], _dir: string, { onOutput }: DockerComposeStreamOptions) => {
        onOutput('    conflict  app/models/spree/brand.rb\nOverwrite? [Ynaqdh] ', 'stdout')
        await new Promise((resolve) => setTimeout(resolve, 300))
        onOutput('       force  app/models/spree/brand.rb\n', 'stdout')
      },
    )

    await run(['generate', 'model', 'Brand'])

    expect(stdout[0]).toBe('Overwrite? [Ynaqdh] ')
    expect(stdout.join('')).toContain('changed   app/models/spree/brand.rb')
  })
})
