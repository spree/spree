import type { CustomFieldDefinition as SdkCustomFieldDefinition } from '@spree/admin-sdk'
import type { RunContext } from '../context.js'
import { numericString } from '../diff.js'
import { ConfigError } from '../errors.js'
import { CUSTOM_FIELD_DEFINITION_ATTRIBUTES, type CustomFieldDefinitionEntry } from '../schema.js'
import type { LiveRecord } from '../types.js'
import { type Payload, pick, present, type Section } from './section.js'

type Definition = SdkCustomFieldDefinition & LiveRecord

const DEFAULT_NAMESPACE = 'custom'

/** What identifies a definition and what kind of value it holds: set on create, fixed afterwards. */
const FIXED = ['resource_type', 'namespace', 'key', 'field_type'] as const

/**
 * A definition's natural key: the resource it attaches to and its namespaced
 * key, e.g. `product:custom.material`. A key written without a namespace is
 * in the default one.
 */
function definitionKey(resourceType: string, key: string): string {
  return `${resourceType}:${key.includes('.') ? key : `${DEFAULT_NAMESPACE}.${key}`}`
}

export const customFieldDefinitions: Section<CustomFieldDefinitionEntry, Definition> = {
  name: 'custom_field_definitions',
  scope: 'write_settings',
  introspectByDefault: true,
  path: '/custom_field_definitions',
  keyAttribute: 'key',
  keyFields: ['resource_type', 'namespace', 'key'],
  // The key is three attributes together, so the section is listed whole.
  filterable: false,
  liveKey: (live) => definitionKey(String(live.resource_type), `${live.namespace}.${live.key}`),
  entries: (config) => config.custom_field_definitions ?? [],
  entryKey: (entry) =>
    definitionKey(entry.resource_type, `${entry.namespace ?? DEFAULT_NAMESPACE}.${entry.key}`),
  async desired(entry) {
    // Sent even when the file leaves it out: servers before 6.1 refuse a
    // definition without a namespace.
    return { namespace: DEFAULT_NAMESPACE, ...pick(entry, CUSTOM_FIELD_DEFINITION_ATTRIBUTES) }
  },
  async current(live, _ctx, desired, entry) {
    // Values already stored are of the live type; the API ignores the change.
    if (desired.field_type !== live.field_type) {
      throw new ConfigError(
        `the live definition is a ${live.field_type} field and a field type cannot change; remove the definition first, or give this one another key`,
        `${entry.resource_type}:${entry.key}`,
      )
    }
    return live
  },
  async update(live, payload, _entry, ctx) {
    const body = { ...payload }
    for (const attribute of FIXED) delete body[attribute]
    return ctx.client.request<Definition>('PATCH', `/custom_field_definitions/${live.id}`, { body })
  },
  async toFile(live) {
    const entry = present(
      live as unknown as CustomFieldDefinitionEntry,
      CUSTOM_FIELD_DEFINITION_ATTRIBUTES,
    ) as CustomFieldDefinitionEntry
    // What the API sets anyway.
    if (entry.namespace === DEFAULT_NAMESPACE) delete entry.namespace
    if (entry.storefront_visible === true) delete entry.storefront_visible
    if (entry.searchable === false) delete entry.searchable
    if (entry.sortable === false) delete entry.sortable
    return entry
  },
}

// --- Values ------------------------------------------------------------------

type Values = Record<string, unknown>

interface LiveCustomField {
  key: string
  field_type?: string
  value: unknown
  custom_field_definition_id: string
}

const fullKey = (key: string) => (key.includes('.') ? key : `${DEFAULT_NAMESPACE}.${key}`)

const liveFields = (live: LiveRecord) => (live.custom_fields as LiveCustomField[] | undefined) ?? []

/** The definitions a section's entries set values for, so they load with the section. */
export function customFieldReferences(
  resourceType: string,
  entries: { custom_fields?: Values }[],
): string[] {
  return entries.flatMap((entry) =>
    Object.keys(entry.custom_fields ?? {}).map((key) => definitionKey(resourceType, key)),
  )
}

/**
 * The values an entry sets, by the keys the file uses, so a plan shows them
 * the way they were written. Every key must name a definition that exists or
 * that the file declares.
 */
export async function customFieldsPayload(
  resourceType: string,
  values: Values | undefined,
  ctx: RunContext,
  path: string,
): Promise<Payload> {
  if (!values) return {}
  await Promise.all(
    Object.keys(values).map((key) =>
      ctx.ref('custom_field_definitions', definitionKey(resourceType, key), path),
    ),
  )
  return {
    custom_fields: Object.fromEntries(
      Object.entries(values).map(([key, value]) => [key, value ?? null]),
    ),
  }
}

/**
 * The live values of the fields the entry sets, under the entry's keys. The
 * write is partial, so fields the file leaves out take no part.
 */
export function liveCustomFields(live: LiveRecord, desired: Payload): Payload {
  const wanted = desired.custom_fields as Values | undefined
  if (!wanted) return {}
  const fields = liveFields(live)
  return {
    custom_fields: Object.fromEntries(
      Object.keys(wanted).map((key) => [
        key,
        fields.find((field) => field.key === fullKey(key))?.value ?? null,
      ]),
    ),
  }
}

/**
 * The request body with its values as the API takes them inline: one entry
 * per definition, which the API creates, changes or (for `null`) removes.
 */
export async function withCustomFieldsBody(
  resourceType: string,
  body: Payload,
  ctx: RunContext,
): Promise<Payload> {
  const values = body.custom_fields as Values | undefined
  if (!values) return body
  return {
    ...body,
    custom_fields: await Promise.all(
      Object.entries(values).map(async ([key, value]) => ({
        custom_field_definition_id: ctx.materialize(
          await ctx.ref('custom_field_definitions', definitionKey(resourceType, key), key),
        ),
        value,
      })),
    ),
  }
}

/** A live record's values as the file writes them, keys in the default namespace left bare. */
export function customFieldsToFile(live: LiveRecord): { custom_fields?: Values } {
  const fields = liveFields(live)
  if (!fields.length) return {}
  const prefix = `${DEFAULT_NAMESPACE}.`
  return {
    custom_fields: Object.fromEntries(
      fields.map((field) => [
        field.key.startsWith(prefix) ? field.key.slice(prefix.length) : field.key,
        // A number field reads back as a decimal string.
        field.field_type === 'number' && typeof field.value === 'string'
          ? (numericString(field.value) ?? field.value)
          : field.value,
      ]),
    ),
  }
}
