import type { RunContext, SectionSource } from '../context.js'
import type { PendingRef } from '../diff.js'
import type { SpreeConfig } from '../schema.js'
import type { AttributeChange, LiveRecord, SectionName } from '../types.js'

export type Payload = Record<string, unknown>

/**
 * How one section of the file maps onto one Admin API resource: which
 * records it lists, how a file entry becomes a request body, how a live
 * record reads back as an entry, and any writes beyond the resource itself.
 */
/**
 * How one section of the file maps onto one Admin API resource.
 *
 * `Entry` is the file's own shape (inferred from the section's Zod schema)
 * and `Live` is the record as the API returns it — the SDK's generated type
 * for that resource, so reading an attribute the API does not have is a
 * compile error rather than a silent `undefined`.
 */
export interface Section<Entry = unknown, Live extends LiveRecord = LiveRecord>
  extends Omit<SectionSource, 'fileKeys'> {
  name: SectionName
  /** The write scope a secret key needs to deploy this section. */
  scope: string
  /** The store section: one record, update only. */
  singleton?: boolean
  /** Entries write one at a time, in order (parents before children). */
  sequential?: boolean
  /** Listed by `introspect` when no `--include` is given. */
  introspectByDefault: boolean
  entries(config: SpreeConfig): Entry[]
  entryKey(entry: Entry): string
  /** Request body for the entry, references resolved to ids or pending refs. */
  desired(entry: Entry, ctx: RunContext, path: string): Promise<Payload>
  /** The live record in the same attribute vocabulary as `desired`, for comparison; the record itself when not given. */
  current?(live: Live, ctx: RunContext, desired?: Payload): Promise<Payload>
  /** Natural keys of other sections this section's entries refer to, so they load in one request per section. */
  references?(config: SpreeConfig): Partial<Record<string, string[]>>
  create?(payload: Payload, entry: Entry, ctx: RunContext): Promise<Live>
  update?(live: Live, payload: Payload, entry: Entry, ctx: RunContext): Promise<Live>
  remove?(live: Live, ctx: RunContext): Promise<void>
  /** Writes that go through other endpoints once the record exists (stock, publication, approval). */
  afterWrite?(entry: Entry, live: Live, changes: AttributeChange[], ctx: RunContext): Promise<void>
  toFile(live: Live, ctx: RunContext): Promise<Entry>
}

/**
 * A section as the registry holds it. Each section is written against its own
 * file entry and its own Admin API type; the engine calls them uniformly, so
 * the registry keeps the shape and drops the two type parameters.
 */
export type AnySection = Section<never, LiveRecord>

/** `{ guest_checkout: false }` → `{ preferred_guest_checkout: false }`. */
export function preferencesPayload(preferences: Record<string, unknown> | undefined): Payload {
  if (!preferences) return {}
  return Object.fromEntries(
    Object.entries(preferences).map(([key, value]) => [`preferred_${key}`, value]),
  )
}

export type PreferenceValue = string | number | boolean | null

/** The `preferred_*` attributes of a live record, back in file form. Only scalars: a file cannot carry the rest. */
export function preferencesFromLive(
  live: LiveRecord,
  only?: string[],
): Record<string, PreferenceValue> {
  const preferences: Record<string, PreferenceValue> = {}
  for (const [attribute, value] of Object.entries(live)) {
    if (!attribute.startsWith('preferred_') || value === null || value === undefined) continue
    if (!['string', 'number', 'boolean'].includes(typeof value)) continue
    const key = attribute.slice('preferred_'.length)
    if (only && !only.includes(key)) continue
    preferences[key] = value as PreferenceValue
  }
  return preferences
}

/** Resolves a list of natural keys to ids (or pending refs), reporting against `path`. */
export async function refs(
  ctx: RunContext,
  section: string,
  keys: string[] | undefined,
  path: string,
): Promise<(string | PendingRef)[] | undefined> {
  if (!keys) return undefined
  return Promise.all(keys.map((key) => ctx.ref(section, key, path)))
}

/** Natural keys for a list of live ids; ids that resolve to nothing are dropped. */
export async function keysOf(ctx: RunContext, section: string, ids: unknown): Promise<string[]> {
  const keys = await Promise.all(
    (Array.isArray(ids) ? (ids as string[]) : []).map((id) => ctx.keyOf(section, id)),
  )
  return keys.filter((key): key is string => key !== null)
}

/** Copies the attributes the file may set, dropping undefined ones. */
export function pick<T extends object>(source: T, attributes: (keyof T)[]): Payload {
  const payload: Payload = {}
  for (const attribute of attributes) {
    const value = source[attribute]
    if (value !== undefined) payload[attribute as string] = value
  }
  return payload
}

/** The attributes of a live record worth writing to a file: set, and not empty. */
export function present<T extends object>(source: T, attributes: (keyof T)[]): Partial<T> {
  const entry: Partial<T> = {}
  for (const attribute of attributes) {
    const value = source[attribute]
    if (value === undefined || value === null || value === '') continue
    if (Array.isArray(value) && value.length === 0) continue
    entry[attribute] = value
  }
  return entry
}

/** Operator-owned rows only, on tables a marketplace's sellers also write to. */
export const FIRST_PARTY = { 'q[seller_id_null]': 1 } as const
