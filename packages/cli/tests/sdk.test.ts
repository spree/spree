import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  realpathSync,
  rmSync,
  writeFileSync,
} from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { Command } from 'commander'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { stringify } from 'yaml'
import { generate, registerSdkCommand, responseTypes } from '../src/commands/sdk'

vi.mock('@clack/prompts', () => ({ log: { success: vi.fn(), error: vi.fn(), info: vi.fn() } }))
vi.mock('execa', () => ({ execa: vi.fn(async () => ({ exitCode: 0 })) }))

const predicates = {
  text: [
    'eq',
    'not_eq',
    'in',
    'not_in',
    'cont',
    'i_cont',
    'not_cont',
    'start',
    'end',
    'null',
    'not_null',
    'present',
    'blank',
  ],
  decimal: ['eq', 'not_eq', 'in', 'not_in', 'lt', 'lteq', 'gt', 'gteq', 'null', 'not_null'],
  integer: ['eq', 'not_eq', 'in', 'not_in', 'lt', 'lteq', 'gt', 'gteq', 'null', 'not_null'],
  date: ['eq', 'not_eq', 'in', 'not_in', 'lt', 'lteq', 'gt', 'gteq', 'null', 'not_null'],
  datetime: ['eq', 'not_eq', 'in', 'not_in', 'lt', 'lteq', 'gt', 'gteq', 'null', 'not_null'],
  enum: ['eq', 'not_eq', 'in', 'not_in', 'null', 'not_null'],
  id: ['eq', 'not_eq', 'in', 'not_in', 'null', 'not_null'],
  type: ['eq', 'not_eq', 'in', 'not_in', 'null', 'not_null'],
  boolean: ['eq', 'not_eq', 'in', 'not_in', 'true', 'false', 'null'],
}

// An extension's admin document: a filtered list, a member action with a
// body, and one without.
const adminSpec = {
  paths: {
    '/api/v3/admin/quotes': {
      get: {
        summary: 'List quotes',
        parameters: [{ name: 'page', in: 'query' }],
        'x-spree-filters': { table: 'Quote', sortable: ['number', 'valid_until'] },
      },
    },
    '/api/v3/admin/quotes/{id}/send': {
      patch: {
        summary: 'Send a quote',
        description: 'Freezes a revision and emails the buyer.',
        requestBody: {
          required: true,
          content: {
            'application/json': { schema: { $ref: '#/components/schemas/SendQuoteParams' } },
          },
        },
      },
    },
    '/api/v3/admin/quotes/{id}/cancel': { patch: { summary: 'Cancel a quote' } },
    '/api/v3/admin/quote_settings': { get: { summary: 'Read the quote settings' } },
  },
  components: {
    schemas: {
      SendQuoteParams: {
        type: 'object',
        properties: {
          valid_until: { type: 'string', format: 'date', nullable: true },
          currency: { $ref: '#/components/schemas/CurrencyCode' },
        },
      },
      CurrencyCode: { type: 'string', enum: ['EUR', 'USD'] },
    },
    'x-spree-filter-tables': {
      Quote: { attributes: { number: 'text', status: 'text' }, associations: {}, scopes: {} },
    },
    'x-spree-filter-predicates': predicates,
  },
}

async function run(argv: string[]) {
  const program = new Command()
  registerSdkCommand(program)
  await program.parseAsync(['sdk', 'generate', ...argv], { from: 'user' })
}

describe('spree sdk generate', () => {
  let dir: string
  let cwd: string
  const out = () => join(dir, 'src/generated')
  const read = (path: string) => readFileSync(join(out(), path), 'utf8')

  beforeEach(() => {
    vi.clearAllMocks()
    cwd = process.cwd()
    dir = realpathSync(mkdtempSync(join(tmpdir(), 'spree-sdk-generate-')))
    process.chdir(dir)
    mkdirSync('ext/openapi', { recursive: true })
    writeFileSync('ext/openapi/admin.yaml', stringify(adminSpec))
    // What `rake spree:sdk:serializer_types` would have written.
    mkdirSync('src/generated/admin/types', { recursive: true })
    writeFileSync(
      'src/generated/admin/types/index.ts',
      "export type { Quote } from './Quote'\nexport type { QuoteSettings } from './QuoteSettings'\n",
    )
    writeFileSync(
      'package.json',
      JSON.stringify({ name: 'my-quotes-extension', spree: { extension: 'ext' } }),
    )
  })

  afterEach(() => {
    process.chdir(cwd)
    process.exitCode = undefined
  })

  it('writes a namespace per resource, named and shaped like the SDK methods', async () => {
    await run(['--no-backend'])

    const client = read('admin/client.ts')
    expect(client).toContain(
      "import { defineAdminExtension, type Client, type ListParams, type PaginatedResponse, type RequestOptions } from '@spree/admin-sdk'",
    )
    expect(client).toContain("export const quotes = defineAdminExtension('quotes'")
    expect(client).toContain(
      'list: (params?: ListParams<QuoteFilters, QuoteSort>, options?: RequestOptions): Promise<PaginatedResponse<Quote>> =>',
    )
    expect(client).toContain(
      'send: (id: string, params: SendQuoteParams, options?: RequestOptions): Promise<Quote> =>',
    )
    expect(client).toContain(
      // biome-ignore lint/suspicious/noTemplateCurlyInString: the generated source, as written
      "request<Quote>('PATCH', `/quotes/${id}/send`, { ...options, body: params })",
    )
    expect(client).toContain('cancel: (id: string, options?: RequestOptions): Promise<Quote> =>')
    expect(client).toContain('   * Freezes a revision and emails the buyer.')
    expect(client).toContain("export const quoteSettings = defineAdminExtension('quoteSettings'")
    expect(client).toContain(
      'get: (params?: { expand?: string[] }, options?: RequestOptions): Promise<QuoteSettings> =>',
    )
    expect(client).toContain('client.extend(quotes).extend(quoteSettings)')
  })

  it('writes the request and filter types beside the client', async () => {
    await run(['--no-backend'])

    expect(read('admin/params/SendQuoteParams.ts')).toContain(
      "import type { CurrencyCode } from '@spree/admin-sdk'",
    )
    expect(read('admin/filters.ts')).toContain("declare module 'my-quotes-extension'")
    expect(read('admin/filters.ts')).not.toContain('spree filters types')
  })

  it('runs the extension rake tasks first, outside the CLI bundle', async () => {
    const { execa } = await import('execa')
    process.env.BUNDLE_GEMFILE = '/somewhere/else/Gemfile'

    await run([])

    expect(execa).toHaveBeenCalledWith(
      'bundle',
      ['exec', 'rake', 'spree:openapi:generate', 'spree:sdk:serializer_types', `OUT=${out()}`],
      expect.objectContaining({
        cwd: join(dir, 'ext'),
        extendEnv: false,
        env: expect.not.objectContaining({ BUNDLE_GEMFILE: expect.anything() }),
      }),
    )
    delete process.env.BUNDLE_GEMFILE
  })

  it('stops when the rake tasks fail', async () => {
    const { execa } = await import('execa')
    vi.mocked(execa).mockResolvedValueOnce({ exitCode: 1 } as never)

    await run([])

    expect(process.exitCode).toBe(1)
    expect(existsSync(join(out(), 'admin/client.ts'))).toBe(false)
  })

  it('types a response it has no type for as unknown', () => {
    rmSync(join(out(), 'admin/types'), { recursive: true })

    generate(join(dir, 'ext'), out())

    expect(read('admin/client.ts')).toContain('Promise<unknown>')
    expect(read('admin/client.ts')).not.toContain("from './spree'")
  })

  it('removes the client and types of an API the extension no longer documents', async () => {
    mkdirSync(join(out(), 'store/params'), { recursive: true })
    writeFileSync(join(out(), 'store/client.ts'), '')

    await run(['--no-backend'])

    expect(existsSync(join(out(), 'store/client.ts'))).toBe(false)
    expect(existsSync(join(out(), 'store/params'))).toBe(false)
    expect(existsSync(join(out(), 'admin/types/index.ts'))).toBe(true)
  })

  it('passes --check when the files are current and fails when they are not', async () => {
    await run(['--no-backend'])
    await run(['--no-backend', '--check'])
    expect(process.exitCode).toBeUndefined()

    writeFileSync(join(out(), 'admin/client.ts'), '// edited')
    await run(['--no-backend', '--check'])

    expect(process.exitCode).toBe(1)
    expect(read('admin/client.ts')).toBe('// edited')
  })

  it('names a nested list and create apart from a member action', () => {
    const nested = structuredClone(adminSpec) as typeof adminSpec & {
      paths: Record<string, unknown>
    }
    nested.paths['/api/v3/admin/quotes/{id}/notes'] = {
      get: { summary: 'List notes', parameters: [{ name: 'page', in: 'query' }] },
      post: { summary: 'Add a note' },
    }
    writeFileSync('ext/openapi/admin.yaml', stringify(nested))

    generate(join(dir, 'ext'), out())

    const client = read('admin/client.ts')
    expect(client).toContain('listNotes: (id: string, params?: ListParams')
    expect(client).toContain('notes: (id: string, options?: RequestOptions)')
  })

  it('refuses two operations that would make one method', () => {
    const clash = structuredClone(adminSpec) as typeof adminSpec & {
      paths: Record<string, unknown>
    }
    clash.paths['/api/v3/admin/quotes/send'] = { post: { summary: 'Send many' } }
    writeFileSync('ext/openapi/admin.yaml', stringify(clash))

    expect(() => generate(join(dir, 'ext'), out())).toThrow(
      /would both be quotes.send; name one with x-spree-sdk-method/,
    )
  })

  it('keeps an action in its resource namespace when the resource itself is not documented', () => {
    const actions = {
      paths: {
        '/api/v3/admin/quotes/{id}/send': adminSpec.paths['/api/v3/admin/quotes/{id}/send'],
      },
      components: adminSpec.components,
    }
    writeFileSync('ext/openapi/admin.yaml', stringify(actions))

    generate(join(dir, 'ext'), out())

    const client = read('admin/client.ts')
    expect(client).toContain("export const quotes = defineAdminExtension('quotes'")
    expect(client).toContain(
      'send: (id: string, params: SendQuoteParams, options?: RequestOptions): Promise<Quote>',
    )
  })

  it('refuses a namespace that is not an identifier, and merges spellings of one', () => {
    const spelled = structuredClone(adminSpec) as typeof adminSpec & {
      paths: Record<string, unknown>
    }
    spelled.paths['/api/v3/admin/quote_notes'] = { post: { summary: 'Add a note' } }
    spelled.paths['/api/v3/admin/quote_notes/{id}'] = {
      delete: { summary: 'Remove a note', 'x-spree-sdk-namespace': 'quoteNotes' },
    }
    writeFileSync('ext/openapi/admin.yaml', stringify(spelled))

    generate(join(dir, 'ext'), out())
    expect(read('admin/client.ts').match(/export const quoteNotes =/g)).toHaveLength(1)

    spelled.paths['/api/v3/admin/quote_notes'] = {
      post: { summary: 'Add a note', 'x-spree-sdk-namespace': 'default' },
    }
    writeFileSync('ext/openapi/admin.yaml', stringify(spelled))
    expect(() => generate(join(dir, 'ext'), out())).toThrow(
      /namespace default, which is not an identifier/,
    )
  })

  it('names a method and its namespace apart from the operationId', () => {
    const named = structuredClone(adminSpec) as typeof adminSpec & {
      paths: Record<string, unknown>
    }
    named.paths['/api/v3/admin/quotes/{id}/attachments/{attachment_id}'] = {
      delete: {
        summary: 'Remove a file',
        operationId: 'quotes_remove_file',
        'x-spree-sdk-method': 'remove_attachment',
      },
    }
    named.paths['/api/v3/admin/orders/{order_id}/quote_files'] = {
      post: {
        summary: 'Presign a file',
        'x-spree-sdk-method': 'presign_file',
        'x-spree-sdk-namespace': 'quotes',
      },
    }
    writeFileSync('ext/openapi/admin.yaml', stringify(named))

    generate(join(dir, 'ext'), out())

    const client = read('admin/client.ts')
    expect(client).toContain('removeAttachment: (id: string, attachmentId: string')
    expect(client).not.toContain('quotesRemoveFile')
    expect(client).toContain('presignFile: (orderId: string, options?: RequestOptions)')
    expect(client).not.toContain("defineAdminExtension('quoteFiles'")
  })

  it('types a response declared inline from its schema', () => {
    const inline = structuredClone(adminSpec) as typeof adminSpec & {
      paths: Record<string, unknown>
    }
    inline.paths['/api/v3/admin/quotes/statuses'] = {
      get: {
        summary: 'List quote statuses',
        responses: {
          '200': {
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  required: ['data'],
                  properties: {
                    data: {
                      type: 'array',
                      items: {
                        type: 'object',
                        required: ['value', 'count'],
                        properties: { value: { type: 'string' }, count: { type: 'integer' } },
                      },
                    },
                    latest: { $ref: '#/components/schemas/Quote' },
                  },
                },
              },
            },
          },
        },
      },
    }
    writeFileSync('ext/openapi/admin.yaml', stringify(inline))

    generate(join(dir, 'ext'), out())

    const client = read('admin/client.ts')
    expect(client).toContain('export type QuotesStatusesResponse = {')
    expect(client).toContain('  data: {\n    value: string\n    count: number\n  }[]')
    expect(client).toContain('  latest?: Quote')
    expect(client).toContain(
      'statuses: (params?: { expand?: string[] }, options?: RequestOptions): Promise<QuotesStatusesResponse> =>',
    )
  })

  it('does not wrap an inline list response in a page, and refuses two inline types of one name', () => {
    const inline = structuredClone(adminSpec) as typeof adminSpec & {
      paths: Record<string, Record<string, Record<string, unknown>>>
    }
    const page = {
      type: 'object',
      properties: { data: { type: 'array', items: { $ref: '#/components/schemas/Quote' } } },
    }
    inline.paths['/api/v3/admin/quotes'].get.responses = {
      '200': { content: { 'application/json': { schema: page } } },
    }
    writeFileSync('ext/openapi/admin.yaml', stringify(inline))

    generate(join(dir, 'ext'), out())
    const client = read('admin/client.ts')
    expect(client).toContain('Promise<QuotesListResponse>')
    expect(client).not.toContain('PaginatedResponse')

    // `quotes.listGet` and `quotesList.get` would both declare QuotesListGetResponse.
    const inlineRead = {
      responses: { '200': { content: { 'application/json': { schema: page } } } },
    }
    inline.paths['/api/v3/admin/quotes/list_get'] = { get: { summary: 'One', ...inlineRead } }
    inline.paths['/api/v3/admin/quote_settings'].get = {
      summary: 'Two',
      'x-spree-sdk-namespace': 'quotes_list',
      ...inlineRead,
    }
    writeFileSync('ext/openapi/admin.yaml', stringify(inline))
    expect(() => generate(join(dir, 'ext'), out())).toThrow(
      /would declare the response type QuotesListGetResponse, which GET .* declares too/,
    )
  })

  it('refuses a request type name that is not an identifier', () => {
    const schemas = { '../../escapeParams': { type: 'object', properties: {} } }
    writeFileSync('ext/openapi/admin.yaml', stringify({ paths: {}, components: { schemas } }))

    expect(() => generate(join(dir, 'ext'), out())).toThrow(/not a request type name/)
    expect(existsSync(join(dir, 'src/escapeParams.ts'))).toBe(false)
  })

  it('asks which extension when none is configured', async () => {
    writeFileSync('package.json', JSON.stringify({ name: 'x' }))

    await run(['--no-backend'])

    expect(process.exitCode).toBe(1)
  })

  it('says so when the extension has no documents', async () => {
    rmSync('ext/openapi/admin.yaml')

    await run(['--no-backend'])

    expect(process.exitCode).toBe(1)
  })

  it('reads the response types the serializer task wrote', () => {
    expect(responseTypes(join(out(), 'admin'))).toEqual(new Set(['Quote', 'QuoteSettings']))
  })
})
