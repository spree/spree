import type { RunContext } from '../context.js'
import { decimalString } from '../spec.js'
import { filePreferences, keysOf, type Payload, refs } from './section.js'

/**
 * Rules, actions and calculators come in registered kinds, each with its own
 * settings. The API lists every kind with a schema of those settings, and
 * that schema is what tells the engine how to carry a setting between the
 * file and the API: an amount is written as a number and sent as a decimal
 * string, and a list of ids is written as natural keys.
 */

export interface PreferenceSchema {
  type?: string | string[]
  format?: string
  pattern?: string
  items?: { 'x-spree-prefix'?: string }
}

export interface KindDefinition {
  type: string
  schema?: { properties?: Record<string, PreferenceSchema> }
}

interface TypedEntry {
  id?: string
  type?: unknown
  active?: unknown
  preferences?: Record<string, unknown>
  calculator?: { type?: unknown; preferences?: Record<string, unknown> } | null
}

/** The section whose records a prefixed id belongs to. */
const SECTION_BY_PREFIX: Record<string, string> = {
  cg: 'customer_groups',
  ch: 'channels',
  mkt: 'markets',
  cust: 'customers',
}

const kindLists = new WeakMap<RunContext, Map<string, Promise<KindDefinition[]>>>()

/**
 * The kinds an endpoint lists, with their setting schemas, read once per run.
 * A listing that depends on another kind names it in the path's query string.
 */
export function kindsAt(ctx: RunContext, path: string): Promise<KindDefinition[]> {
  const lists = kindLists.get(ctx) ?? new Map<string, Promise<KindDefinition[]>>()
  kindLists.set(ctx, lists)
  let kinds = lists.get(path)
  if (!kinds) {
    const [resource, query] = path.split('?')
    kinds = ctx.client
      .request<{ data: KindDefinition[] }>('GET', resource, {
        params: Object.fromEntries(new URLSearchParams(query ?? '')),
      })
      .then((response) => response.data)
    lists.set(path, kinds)
  }
  return kinds
}

async function propertiesOf(ctx: RunContext, typesPath: string, type: unknown) {
  const kinds = await kindsAt(ctx, typesPath)
  return kinds.find((kind) => kind.type === type)?.schema?.properties ?? {}
}

/**
 * An amount, rate or percentage: a string (possibly nullable) in money or
 * decimal format, or a percentage that only carries the decimal pattern.
 */
function isDecimalPreference(schema: PreferenceSchema | undefined): boolean {
  if (!schema) return false
  const types = Array.isArray(schema.type) ? schema.type : [schema.type]
  if (!types.includes('string')) return false
  return (
    schema.format === 'money' ||
    schema.format === 'decimal' ||
    schema.pattern === String.raw`^-?\d+(\.\d+)?$`
  )
}

function referencedSection(schema: PreferenceSchema | undefined): string | undefined {
  const prefix = schema?.items?.['x-spree-prefix']
  return prefix ? SECTION_BY_PREFIX[prefix] : undefined
}

/** Preferences as the API takes them: amounts the file wrote as numbers go out as decimal strings. */
export async function wirePreferences<Entry extends TypedEntry>(
  entry: Entry,
  typesPath: string,
  ctx: RunContext,
): Promise<Entry> {
  if (!entry.preferences) return entry
  const properties = await propertiesOf(ctx, typesPath, entry.type)
  return {
    ...entry,
    preferences: Object.fromEntries(
      Object.entries(entry.preferences).map(([key, value]) => [
        key,
        isDecimalPreference(properties[key]) ? decimalString(value) : value,
      ]),
    ),
  }
}

/** Rules by kind, so two sets compare whatever order they were written in. */
export function sortedRules<Rule extends { type?: unknown }>(rules: Rule[] | undefined): Rule[] {
  return [...(rules ?? [])].sort((left, right) =>
    String(left.type).localeCompare(String(right.type)),
  )
}

/**
 * Live rules in the order and shape the declared ones are compared in: what a
 * file can say about a rule, and nothing the store adds to it.
 */
export function comparableRules(rules: unknown): Payload[] {
  return sortedRules(rules as TypedEntry[] | undefined).map((rule) => ({
    type: rule.type,
    active: rule.active,
    preferences: rule.preferences ?? {},
    ...(rule.calculator
      ? {
          calculator: {
            type: rule.calculator.type,
            preferences: rule.calculator.preferences ?? {},
          },
        }
      : {}),
  }))
}

/**
 * Declared rules addressed by the id of the live rule of the same kind, so a
 * changed rule is updated in place rather than added beside the old one.
 */
export function withLiveIds(rules: unknown, live: unknown): Payload[] {
  const unused = [...((live as TypedEntry[] | undefined) ?? [])]
  return ((rules as Payload[] | undefined) ?? []).map((rule) => {
    const index = unused.findIndex((candidate) => candidate.type === rule.type)
    if (index < 0) return rule
    const [match] = unused.splice(index, 1)
    return { id: match.id, ...rule }
  })
}

/**
 * The rules an entry declares, ready to compare and send: in a stable order,
 * with every setting that lists records by natural key resolved to ids.
 */
export async function desiredRules(
  rules: TypedEntry[],
  typesPath: string,
  ctx: RunContext,
  path: string,
): Promise<Payload[]> {
  return Promise.all(
    sortedRules(rules).map(async (rule) => {
      if (!rule.preferences) return { ...rule }
      const properties = await propertiesOf(ctx, typesPath, rule.type)
      const preferences: Payload = {}
      for (const [key, value] of Object.entries(rule.preferences)) {
        const section = referencedSection(properties[key])
        preferences[key] =
          section && Array.isArray(value)
            ? await refs(ctx, section, value as string[], path)
            : value
      }
      return { ...rule, preferences }
    }),
  )
}

/** A rule set as the API takes it. */
export function wireRules(rules: unknown, typesPath: string, ctx: RunContext) {
  return Promise.all(
    ((rules as TypedEntry[] | undefined) ?? []).map((rule) =>
      wirePreferences(rule, typesPath, ctx),
    ),
  )
}

/**
 * Live rules as the file writes them: the kind, a switched-off flag, and the
 * settings that are set, with ids turned back into natural keys.
 */
export async function rulesToFile(
  rules: TypedEntry[] | undefined,
  typesPath: string,
  ctx: RunContext,
) {
  return Promise.all(
    sortedRules(rules).map(async (rule) => {
      const properties = await propertiesOf(ctx, typesPath, rule.type)
      const preferences: Record<string, unknown> = filePreferences(rule.preferences)
      for (const [key, value] of Object.entries(preferences)) {
        const section = referencedSection(properties[key])
        if (section) preferences[key] = await keysOf(ctx, section, value)
      }
      return {
        type: String(rule.type),
        ...(rule.active === false ? { active: false } : {}),
        ...(Object.keys(preferences).length ? { preferences } : {}),
      }
    }),
  )
}
