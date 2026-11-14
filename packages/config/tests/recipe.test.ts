import { describe, expect, it } from 'vitest'
import { deployStep, importStep, RecipeError, type RecipeStep, runRecipe } from '../src/node'
import { sampleData } from '../src/sample-data'
import { FakeApi } from './fake-api'

/** The in-memory API with uploads, and imports that finish after a number of polls. */
class RecipeApi extends FakeApi {
  readonly uploads: { filename?: string; text: string }[] = []
  /** How an import ends: its final status and how many of its rows failed. */
  outcome = { status: 'completed', failed_rows_count: 0, processing_errors: null as string | null }
  pollsUntilDone = 2
  private polls = 0

  files = {
    upload: async (file: Blob, options: { filename?: string } = {}) => {
      this.uploads.push({ filename: options.filename, text: await file.text() })
      return { signed_id: `signed_${this.uploads.length}` }
    },
  }

  constructor() {
    super()
    const request = this.request
    this.request = async (method, path, options) => {
      if (method === 'PATCH' && /^\/imports\/[^/]+\/complete_mapping$/.test(path)) {
        this.calls.push({ method, path, body: options?.body })
        return undefined as never
      }
      if (method === 'GET' && /^\/imports\/[^/]+\/rows$/.test(path)) {
        return {
          data: [{ id: 'row_1', row_number: 3, validation_errors: 'Slug is taken' }],
        } as never
      }
      if (method === 'GET' && /^\/imports\/[^/]+$/.test(path)) {
        this.calls.push({ method, path })
        this.polls += 1
        const done = this.polls >= this.pollsUntilDone
        return {
          id: path.split('/')[2],
          ...(done ? this.outcome : { status: 'processing' }),
        } as never
      }
      return request(method, path, options)
    }
  }
}

const products = (overrides = {}) =>
  importStep('Importing products', {
    type: 'products',
    csv: 'slug,name\ntee,Tee\n',
    filename: 'products.csv',
    pollMs: 0,
    ...overrides,
  })

describe('runRecipe', () => {
  it('runs the steps in order, reporting each as it starts', async () => {
    const api = new RecipeApi()
    api.seed('/channels', [])
    const seen: string[] = []
    const steps: RecipeStep[] = [
      deployStep(
        'Adding a channel',
        'version: 1\nchannels:\n  - code: ${CODE}\n    name: POS\n',
        async () => ({
          CODE: 'pos',
        }),
      ),
      products(),
    ]
    await runRecipe(api, steps, {
      onStep: ({ step, number, total }) => seen.push(`${number}/${total} ${step.title}`),
    })
    expect(seen).toEqual(['1/2 Adding a channel', '2/2 Importing products'])
    expect(api.all('/channels')[0].code).toBe('pos')
  })

  it('stops at the step that fails and says which', async () => {
    const api = new RecipeApi()
    const ran: string[] = []
    const step = (title: string, fail = false): RecipeStep => ({
      title,
      async run() {
        ran.push(title)
        if (fail) throw new Error('no such zone')
      },
    })
    const run = runRecipe(api, [step('one'), step('two', true), step('three')])
    await expect(run).rejects.toThrow(RecipeError)
    await expect(run).rejects.toThrow('two failed: no such zone')
    expect(ran).toEqual(['one', 'two'])
  })

  it('reports a store file that deployed with failures', async () => {
    const api = new RecipeApi()
    api.seed('/delivery_methods', [])
    api.seed('/delivery_zones', [])
    const step = deployStep(
      'Adding delivery',
      'version: 1\ndelivery_methods:\n  - name: Express\n    delivery_zone: Domestic\n',
    )
    await expect(runRecipe(api, [step])).rejects.toThrow(/delivery_zones "Domestic"/)
  })
})

describe('importStep', () => {
  it('uploads the CSV, starts the import and waits for it to finish', async () => {
    const api = new RecipeApi()
    await runRecipe(api, [products({ attributes: async () => ({ price_list_id: 'pl_1' }) })])
    expect(api.uploads).toEqual([{ filename: 'products.csv', text: 'slug,name\ntee,Tee\n' }])
    const created = api.calls.find((call) => call.method === 'POST' && call.path === '/imports')
    expect(created?.body).toEqual({
      type: 'products',
      attachment_signed_id: 'signed_1',
      price_list_id: 'pl_1',
    })
    const polls = api.calls.filter(
      (call) => call.method === 'GET' && /^\/imports\//.test(call.path),
    )
    expect(polls).toHaveLength(2)
  })

  it('fails when rows failed, quoting the first of them', async () => {
    const api = new RecipeApi()
    api.outcome = { status: 'completed', failed_rows_count: 4, processing_errors: null }
    await expect(runRecipe(api, [products()])).rejects.toThrow(
      '4 products rows failed (row 3: Slug is taken)',
    )
  })

  it('fails when the import itself failed', async () => {
    const api = new RecipeApi()
    api.outcome = { status: 'failed', failed_rows_count: 0, processing_errors: 'Malformed CSV' }
    await expect(runRecipe(api, [products()])).rejects.toThrow('Malformed CSV')
  })

  it('gives up on an import that never finishes', async () => {
    const api = new RecipeApi()
    api.pollsUntilDone = Number.POSITIVE_INFINITY
    await expect(runRecipe(api, [products({ timeoutMs: -1 })])).rejects.toThrow(
      'the products import did not finish in time',
    )
  })
})

describe('sampleData', () => {
  it('refuses a store that never got its defaults', async () => {
    const api = new RecipeApi()
    api.seed('/stock_locations', [])
    await expect(runRecipe(api, sampleData())).rejects.toThrow(/spree config provision/)
  })

  it('imports the products before the files that build on them', () => {
    const titles = sampleData().map((step) => step.title)
    expect(titles.indexOf('Importing products')).toBeLessThan(
      titles.indexOf('Creating collections'),
    )
    expect(titles.indexOf('Setting up wholesale')).toBeLessThan(
      titles.indexOf('Importing wholesale prices'),
    )
  })
})
