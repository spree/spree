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

/** The `preferred_*` attributes the resource accepts, without the prefix. */
export function writablePreferences(resource: Resource): [string, ...string[]] {
  const names = writableAttributes(resource)
    .filter((name) => name.startsWith('preferred_'))
    .map((name) => name.slice('preferred_'.length))
  if (!names.length) throw new Error(`the Admin API documents no preferences for ${resource}`)
  return names as [string, ...string[]]
}

function scalar(schema: PropertySchema): ZodType {
  if (schema.enum?.length) return z.enum(schema.enum.map(String) as [string, ...string[]])
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
