import { describe, expect, it } from 'vitest'
import { renderParamsTypes } from '../../sdk-core/src/params-types'

describe('renderParamsTypes', () => {
  const files = renderParamsTypes({
    components: {
      schemas: {
        Product: { type: 'object', properties: { id: { type: 'string' } } },
        PriceParams: {
          type: 'object',
          properties: {
            amount: { type: 'string', format: 'decimal' },
            compare_at_amount: { type: 'string', nullable: true },
          },
          required: ['amount'],
        },
        WidgetCreateParams: {
          type: 'object',
          properties: {
            name: { type: 'string', description: 'The name.' },
            status: { type: 'string', enum: ['draft', "it's"] },
            weight: { type: 'number', nullable: true },
            tags: { type: 'array', items: { type: 'string' } },
            metadata: { type: 'object', additionalProperties: true },
            value: {},
            prices: { type: 'array', items: { $ref: '#/components/schemas/PriceParams' } },
            main_price: { allOf: [{ $ref: '#/components/schemas/PriceParams' }], nullable: true },
            options: {
              type: 'array',
              items: {
                type: 'object',
                properties: { name: { type: 'string' } },
                required: ['name'],
              },
            },
          },
          required: ['name'],
        },
      },
    },
  })

  const source = files.get('WidgetCreateParams.ts') ?? ''

  it('writes one file per request schema and an index of them', () => {
    expect([...files.keys()]).toEqual(['PriceParams.ts', 'WidgetCreateParams.ts', 'index.ts'])
    expect(files.get('index.ts')).toContain(
      "export type { PriceParams } from './PriceParams'\nexport type { WidgetCreateParams } from './WidgetCreateParams'\n",
    )
  })

  it('imports the request types a type references', () => {
    expect(source).toContain("import type { PriceParams } from './PriceParams'\n")
  })

  it('maps each kind of value', () => {
    expect(files.get('PriceParams.ts')).toContain(
      '  amount: string\n  compare_at_amount?: string | null\n',
    )
    expect(source).toContain('  /** The name. */\n  name: string\n')
    expect(source).toContain("  status?: 'draft' | 'it\\'s'\n")
    expect(source).toContain('  weight?: number | null\n')
    expect(source).toContain('  tags?: string[]\n')
    expect(source).toContain('  metadata?: Record<string, unknown>\n')
    expect(source).toContain('  value?: unknown\n')
    expect(source).toContain('  prices?: PriceParams[]\n')
    expect(source).toContain('  main_price?: PriceParams | null\n')
    expect(source).toContain('  options?: {\n    name: string\n  }[]\n')
  })

  it('refuses a reference to a response schema', () => {
    expect(() =>
      renderParamsTypes({
        components: {
          schemas: {
            BadParams: {
              type: 'object',
              properties: { product: { $ref: '#/components/schemas/Product' } },
            },
          },
        },
      }),
    ).toThrow(/not a request schema/)
  })
})
