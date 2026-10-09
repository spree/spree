import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { Command } from 'commander'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { parseFilterTables, registerFiltersCommand } from '../src/commands/filters'
import { rakeTask } from '../src/docker'

vi.mock('../src/context', () => ({
  detectProject: () => ({ mode: 'docker', projectDir: '/proj', port: 3000 }),
}))
vi.mock('../src/docker', () => ({ rakeTask: vi.fn() }))
vi.mock('@clack/prompts', () => ({ log: { success: vi.fn(), error: vi.fn() } }))

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

const spec = {
  paths: {
    '/api/v3/store/products': {
      get: { 'x-spree-filters': { table: 'Product', sortable: ['erp_id', 'name'] } },
    },
  },
  components: {
    'x-spree-filter-tables': {
      Product: {
        attributes: { erp_id: 'text', name: 'text' },
        associations: {},
        scopes: { featured: 'boolean' },
      },
    },
    'x-spree-filter-predicates': predicates,
  },
}
const taskOutput = `[Spree Events] booted\n${JSON.stringify({ store: spec, admin: spec, seller: spec })}\n`

async function run(argv: string[]) {
  const program = new Command()
  registerFiltersCommand(program)
  await program.parseAsync(['filters', 'types', ...argv], { from: 'user' })
}

describe('spree filters types', () => {
  let dir: string

  beforeEach(() => {
    vi.clearAllMocks()
    dir = mkdtempSync(join(tmpdir(), 'spree-filters-'))
  })

  it("declares the app's filters and sort fields for the chosen SDK", async () => {
    vi.mocked(rakeTask).mockResolvedValue(taskOutput)
    const out = join(dir, 'spree-filters.d.ts')

    await run(['--api', 'admin', '--out', out])

    const file = readFileSync(out, 'utf8')
    expect(rakeTask).toHaveBeenCalledWith('spree:api:filter_tables', '/proj')
    expect(file).toContain("declare module '@spree/admin-sdk'")
    expect(file).toContain("Filter.TextFilters<'erp_id' | 'name'>")
    expect(file).toContain('interface ProductFilterExtensions extends AppProductFilters {}')
    expect(file).toContain("interface ProductSortExtensions { 'erp_id': true; 'name': true; }")
    expect(file).toContain('featured?: boolean')
  })

  it('reads the tables from a file instead of the running app', async () => {
    const from = join(dir, 'tables.json')
    writeFileSync(from, taskOutput)
    const out = join(dir, 'types', 'spree-filters.d.ts')

    await run(['--from', from, '--out', out])

    expect(rakeTask).not.toHaveBeenCalled()
    expect(readFileSync(out, 'utf8')).toContain("declare module '@spree/sdk'")
  })

  it('refuses output without filter tables', () => {
    expect(() => parseFilterTables('[Spree Events] booted\n')).toThrow(/No filter tables found/)
  })
})
