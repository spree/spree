import { type ZodType, z } from 'zod'
import { WRITABLE } from './generated/writable.js'

/**
 * What the Admin API documents as writable for each resource the
 * configurator manages, extracted from the generated OpenAPI spec by
 * `scripts/extract-writable.mjs`. Sections take their plain attributes from
 * here instead of listing and typing them by hand, so the file accepts
 * exactly what the API does.
 */

type Writable = typeof WRITABLE
export type Resource = keyof Writable

interface PropertySchema {
  readonly type?: string
  readonly format?: string
  readonly nullable?: boolean
  readonly enum?: readonly (string | number)[]
  readonly deprecated?: boolean
  readonly items?: { readonly type?: string }
}

type Properties<Body> = Body extends { properties: infer P } ? P : Record<never, never>

/** Documented properties of a resource, create and update together. */
type PropertiesOf<R extends Resource> = Properties<Writable[R]['create']> &
  Properties<Writable[R]['update']>

type ScalarOf<P> = P extends { enum: readonly (infer E)[] }
  ? E
  : P extends { type: 'string'; format: 'decimal' | 'money' }
    ? number | string
    : P extends { type: 'string' }
      ? string
      : P extends { type: 'boolean' }
        ? boolean
        : P extends { type: 'integer' | 'number' }
          ? number
          : P extends { type: 'array'; items: { type: 'string' } }
            ? string[]
            : P extends { type: 'array' }
              ? unknown[]
              : string | number | boolean

type ValueOf<P> = P extends { nullable: true } ? ScalarOf<P> | null : ScalarOf<P>

/** An attribute name the API documents as writable on the resource. */
export type AttributeOf<R extends Resource> = Extract<keyof PropertiesOf<R>, string>

type ValueOfAttribute<R extends Resource, A extends AttributeOf<R>> = ValueOf<PropertiesOf<R>[A]>

function bodies(resource: Resource): {
  create: { properties: Record<string, PropertySchema> } | null
  update: { properties: Record<string, PropertySchema> } | null
} {
  return WRITABLE[resource] as never
}

function property(resource: Resource, attribute: string): PropertySchema | undefined {
  const { create, update } = bodies(resource)
  return create?.properties[attribute] ?? update?.properties[attribute]
}

/** Every attribute the resource accepts on create or update, deprecated ones excluded. */
export function writableAttributes(resource: Resource): string[] {
  const { create, update } = bodies(resource)
  const names = new Set([
    ...Object.keys(create?.properties ?? {}),
    ...Object.keys(update?.properties ?? {}),
  ])
  return [...names].filter((name) => !property(resource, name)?.deprecated)
}

/**
 * A live record's attributes as the file writes them: the API reads decimals
 * back as strings ("12.0"), and the file types them as numbers.
 */
export function numbersAsNumbers<T extends object>(resource: string, entry: T): T {
  if (!(resource in WRITABLE)) return entry
  const out = { ...entry } as Record<string, unknown>
  for (const [attribute, value] of Object.entries(out)) {
    const schema = property(resource as Resource, attribute)
    const numeric = schema?.type === 'number' || schema?.type === 'integer' || isDecimal(schema)
    if (numeric && typeof value === 'string' && value.trim()) {
      const number = Number(value)
      if (Number.isFinite(number)) out[attribute] = number
    }
  }
  return out as T
}

/** Amounts the API takes as canonical decimal strings, never JSON numbers. */
const DECIMAL = /^-?\d+(\.\d+)?$/

/** A decimal as the API takes it: `29.9` in a file is sent as `"29.9"`. */
export function decimalString(value: unknown): unknown {
  return typeof value === 'number' ? String(value) : value
}

function isDecimal(schema: PropertySchema | undefined): boolean {
  return schema?.type === 'string' && (schema.format === 'decimal' || schema.format === 'money')
}

/**
 * A request body as the API takes it: every decimal attribute the file wrote
 * as a number is sent as a decimal string.
 */
export function asWireValues(resource: string, payload: Record<string, unknown>) {
  if (!(resource in WRITABLE)) return payload
  return Object.fromEntries(
    Object.entries(payload).map(([attribute, value]) => [
      attribute,
      isDecimal(property(resource as Resource, attribute)) ? decimalString(value) : value,
    ]),
  )
}

function scalar(schema: PropertySchema): ZodType {
  if (schema.enum?.length) return z.enum(schema.enum.map(String) as [string, ...string[]])
  // Written as a number or a decimal string; sent as a string.
  if (isDecimal(schema)) return z.union([z.number(), z.string().regex(DECIMAL)])
  switch (schema.type) {
    case 'string':
      return z.string()
    case 'boolean':
      return z.boolean()
    case 'integer':
      return z.number().int()
    case 'number':
      return z.number()
    case 'array':
      return z.array(schema.items?.type ? scalar({ type: schema.items.type }) : z.unknown())
    default:
      return z.union([z.string(), z.number(), z.boolean()])
  }
}

/** The Zod type of one documented attribute, nullable where the API accepts null. */
export function attributeSchema<R extends Resource, A extends AttributeOf<R>>(
  resource: R,
  attribute: A,
): ZodType<ValueOfAttribute<R, A>> {
  const schema = property(resource, attribute)
  if (!schema) throw new Error(`the Admin API documents no writable "${attribute}" on ${resource}`)
  const base = scalar(schema)
  return (schema.nullable ? base.nullable() : base) as ZodType<ValueOfAttribute<R, A>>
}

/**
 * A Zod shape of optional attributes, typed from the spec. An attribute the
 * API does not document is a compile error, and the generated spec is the
 * only list, so a section can never write what the API would silently drop.
 */
export function specShape<R extends Resource, const Names extends readonly AttributeOf<R>[]>(
  resource: R,
  attributes: Names,
): { [Name in Names[number]]: z.ZodOptional<ZodType<ValueOfAttribute<R, Name>>> } {
  return Object.fromEntries(
    attributes.map((attribute) => [attribute, attributeSchema(resource, attribute).optional()]),
  ) as never
}
