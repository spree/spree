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
export interface Section<Entry = unknown> extends SectionSource {
  name: SectionName
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
  /** The live record in the same attribute vocabulary as `desired`, for comparison. Only what the entry mentions needs to be there. */
  current(live: LiveRecord, ctx: RunContext, entry?: Entry): Promise<Payload>
  create?(payload: Payload, entry: Entry, ctx: RunContext): Promise<LiveRecord>
  update?(live: LiveRecord, payload: Payload, entry: Entry, ctx: RunContext): Promise<LiveRecord>
  remove?(live: LiveRecord, ctx: RunContext): Promise<void>
  /** Writes that go through other endpoints once the record exists (stock, publication, approval). */
  afterWrite?(
    entry: Entry,
    live: LiveRecord,
    changes: AttributeChange[],
    ctx: RunContext,
  ): Promise<void>
  toFile(live: LiveRecord, ctx: RunContext): Promise<Entry>
}

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

export function byName(live: LiveRecord): string {
  return String(live.name)
}
