import { describe, expect, it } from 'vitest'
import {
  ConfigValidationError,
  parseConfig,
  substituteEnv,
  toJsonSchema,
} from '../src/config/index'

describe('parseConfig', () => {
  it('parses YAML into a typed config and lists the sections present', () => {
    const { config, sections } = parseConfig(`
version: 1
channels:
  - code: retail
    name: Retail
products:
  - slug: tee
    name: Tee
    sku: TEE
    prices: { USD: 29.99 }
`)
    expect(config.channels?.[0]).toEqual({ code: 'retail', name: 'Retail' })
    expect(config.products?.[0].prices).toEqual({ USD: 29.99 })
    expect(sections).toEqual(['channels', 'products'])
  })

  it('accepts JSON, since YAML is its superset', () => {
    const { config } = parseConfig('{"version": 1, "customer_groups": [{"name": "Wholesale"}]}')
    expect(config.customer_groups?.[0].name).toBe('Wholesale')
  })

  it('reports every schema problem with its path and line', () => {
    const source = `version: 1
markets:
  - name: Europe
    currency: eur
    countries: [DE]
products:
  - slug: tee
    name: Tee
    colour: red
`
    let error: ConfigValidationError | undefined
    try {
      parseConfig(source)
    } catch (caught) {
      error = caught as ConfigValidationError
    }
    expect(error).toBeInstanceOf(ConfigValidationError)
    expect(error?.issues.map((issue) => [issue.path, issue.line])).toEqual([
      ['markets[0].currency', 4],
      ['products[0]', 7],
    ])
    expect(error?.issues[1].message).toMatch(/colour/)
  })

  it('refuses a product declaring both variants and simple-product fields', () => {
    expect(() =>
      parseConfig(`
version: 1
products:
  - slug: tee
    name: Tee
    sku: TEE
    variants:
      - sku: TEE-S
`),
    ).toThrow(/either `variants` or the simple-product/)
  })

  it('reports a YAML syntax error with its line', () => {
    expect(() => parseConfig('version: 1\nchannels:\n  - code: [\n')).toThrow(ConfigValidationError)
  })
})

describe('substituteEnv', () => {
  it('replaces placeholders anywhere in the tree', () => {
    const result = substituteEnv(
      { customers: [{ email: 'a@example.com', password: `$${'{CUSTOMER_PASSWORD}'}` }] },
      { CUSTOMER_PASSWORD: 'secret' },
    )
    expect(result).toEqual({ customers: [{ email: 'a@example.com', password: 'secret' }] })
  })

  it('names the missing variable and where it was used', () => {
    expect(() => substituteEnv({ customers: [{ password: `$${'{MISSING}'}` }] }, {})).toThrow(
      /MISSING is not set/,
    )
    expect(() =>
      parseConfig(
        `version: 1\ncustomers:\n  - email: a@example.com\n    password: $${'{MISSING}'}\n`,
        {},
      ),
    ).toThrow(/customers\[0\]\.password.*MISSING/)
  })
})

describe('toJsonSchema', () => {
  it('emits a draft-7 schema with every section', () => {
    const schema = toJsonSchema() as { $schema: string; properties: Record<string, unknown> }
    expect(schema.$schema).toContain('draft-07')
    expect(Object.keys(schema.properties)).toEqual(
      expect.arrayContaining(['version', 'store', 'channels', 'products', 'customers', 'sellers']),
    )
  })
})
