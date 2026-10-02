import type { RunContext, SectionSource } from '../context.js'
import type { PendingRef } from '../diff.js'
import type { SpreeConfig } from '../schema.js'
import type { AttributeChange, LiveRecord, SectionName } from '../types.js'

export type Payload = Record<string, unknown>

/**
 * How one section of the file maps onto one Admin API resource.
 *
 * `Entry` is the file's own shape (inferred from the section's Zod schema)
 * and `Live` is the record as the API returns it — the SDK's generated type
 * for that resource, so reading an attribute the API does not have is a
 * compile error rather than a silent `undefined`.
 */
export interface Section<Entry = unknown, Live extends LiveRecord = LiveRecord>
  extends Omit<SectionSource, 'fileKeys' | 'readScope'> {
  name: SectionName
  /** The write scope a secret key needs to deploy this section. */
  scope: string
  /** The scope listing it needs, when it is not the write scope's `read_` twin. */
  readScope?: string
  /** The store section: one record, update only. */
  singleton?: boolean
  /** Entries write one at a time, in order (parents before children). */
  sequential?: boolean
  /** Why `--prune` may never name this section, when it may not. */
  pruneRefusal?: string
  /**
   * The endpoint listing the `type` shorthands the installation has
   * registered, for a section whose entries are typed subclasses.
   */
  typesPath?: string
  /** Listed by `introspect` when no `--include` is given. */
  introspectByDefault: boolean
  entries(config: SpreeConfig): Entry[]
  entryKey(entry: Entry): string
  /** Request body for the entry, references resolved to ids or pending refs. */
  desired(entry: Entry, ctx: RunContext, path: string): Promise<Payload>
  /**
   * The live record in the same attribute vocabulary as `desired`, for
   * comparison; the record itself when not given. Throws a ConfigError when
   * the entry cannot be applied to this record.
   */
  current?(live: Live, ctx: RunContext, desired: Payload, entry: Entry): Promise<Payload>
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

/** The scalar values of a preferences hash: a file cannot carry the rest. */
export function scalarPreferences(
  preferences: Record<string, unknown>,
  only?: string[],
): Record<string, PreferenceValue> {
  const scalars: Record<string, PreferenceValue> = {}
  for (const [key, value] of Object.entries(preferences)) {
    if (value === null || value === undefined) continue
    if (!['string', 'number', 'boolean'].includes(typeof value)) continue
    if (only && !only.includes(key)) continue
    scalars[key] = value as PreferenceValue
  }
  return scalars
}

/** The `preferred_*` attributes of a live record, back in file form. */
export function preferencesFromLive(
  live: LiveRecord,
  only?: string[],
): Record<string, PreferenceValue> {
  return scalarPreferences(
    Object.fromEntries(
      Object.entries(live)
        .filter(([attribute]) => attribute.startsWith('preferred_'))
        .map(([attribute, value]) => [attribute.slice('preferred_'.length), value]),
    ),
    only,
  )
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

/**
 * Splits a live id list into the ids the file can name and those it cannot
 * (a seller's warehouse, outside the first-party listing). The file manages
 * only the first; the second is carried through every write untouched.
 */
export async function partitionIds(
  ctx: RunContext,
  section: string,
  ids: unknown,
): Promise<{ named: string[]; unnamed: string[] }> {
  const named: string[] = []
  const unnamed: string[] = []
  for (const id of Array.isArray(ids) ? (ids as string[]) : []) {
    if ((await ctx.keyOf(section, id)) === null) unnamed.push(id)
    else named.push(id)
  }
  return { named, unnamed }
}

/**
 * Compares and writes a reference list the file manages only partly: the
 * comparison sees the ids the file can name, and the write keeps the rest.
 */
export function partialIdList(section: string, attribute: string) {
  return {
    async current(live: LiveRecord, ctx: RunContext, desired: Payload): Promise<Payload> {
      if (desired[attribute] === undefined) return live
      const { named } = await partitionIds(ctx, section, live[attribute])
      return { ...live, [attribute]: named }
    },
    async write(live: LiveRecord, payload: Payload, ctx: RunContext): Promise<Payload> {
      if (!Array.isArray(payload[attribute])) return payload
      const { unnamed } = await partitionIds(ctx, section, live[attribute])
      return { ...payload, [attribute]: [...(payload[attribute] as string[]), ...unnamed] }
    },
  }
}

/** Copies the attributes the file may set, dropping undefined ones. */
export function pick<T extends object>(source: T, attributes: readonly (keyof T)[]): Payload {
  const payload: Payload = {}
  for (const attribute of attributes) {
    const value = source[attribute]
    if (value !== undefined) payload[attribute as string] = value
  }
  return payload
}

/** The attributes of a live record worth writing to a file: set, and not empty. */
export function present<T extends object>(source: T, attributes: readonly (keyof T)[]): Partial<T> {
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

type PlainOptions<Entry, Live extends LiveRecord> = Omit<
  Section<Entry, Live>,
  'entries' | 'entryKey' | 'keyAttribute' | 'path' | 'filterable' | 'desired' | 'toFile'
> & {
  /** The live attribute holding the key, when the API reads it back under another name. */
  keyAttribute?: string
  filterable?: boolean
  /** The attribute the section matches on. */
  key: keyof Entry & string
  /** Attributes written as they are, from the file to the API and back. */
  attributes: readonly (keyof Entry & string)[]
  /** Values `introspect` leaves out because the API sets them anyway. */
  defaults?: Partial<Record<keyof Entry & string, unknown>>
  /** Attributes the API sets on create and ignores afterwards; left out of updates. */
  fixedOnCreate?: readonly (keyof Entry & string)[]
  desired?: Section<Entry, Live>['desired']
  toFile?: Section<Entry, Live>['toFile']
}

/**
 * A section whose entries are plain attributes of one Admin API resource,
 * listed and keyed on one of them, at `/<section name>`. Anything beyond that
 * (references, nested writes) overrides `desired` and `toFile`; whatever
 * `toFile` returns still has the `defaults` taken out.
 */
export function plainSection<Entry extends object, Live extends LiveRecord>(
  options: PlainOptions<Entry, Live>,
): Section<Entry, Live> {
  const { key, attributes, defaults = {}, fixedOnCreate = [], toFile, ...rest } = options
  const path = `/${options.name}`
  return {
    path,
    keyAttribute: key,
    filterable: true,
    entries: (config) => (config[options.name] ?? []) as Entry[],
    entryKey: (entry) => String(entry[key]),
    async desired(entry) {
      return pick(entry, attributes)
    },
    ...(fixedOnCreate.length
      ? {
          async update(live: Live, payload: Payload, _entry: Entry, ctx: RunContext) {
            const body = { ...payload }
            for (const attribute of fixedOnCreate) delete body[attribute]
            return ctx.client.request<Live>('PATCH', `${path}/${live.id}`, { body })
          },
        }
      : {}),
    ...rest,
    async toFile(live, ctx) {
      const entry = toFile
        ? await toFile(live, ctx)
        : (present(live as unknown as Entry, attributes) as Entry)
      for (const [attribute, value] of Object.entries(defaults)) {
        if (entry[attribute as keyof Entry] === value) delete entry[attribute as keyof Entry]
      }
      return entry
    },
  }
}
