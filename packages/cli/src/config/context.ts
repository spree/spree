import { listAll, listByKeys } from './client.js'
import { PendingRef } from './diff.js'
import { ConfigError, DanglingReferenceError } from './errors.js'
import type { SpreeConfig } from './schema.js'
import type { ConfigClient, LiveRecord } from './types.js'

export interface LiveSection {
  /** Live records keyed on their natural key; a key with several records holds them all. */
  byKey: Map<string, LiveRecord[]>
  /** True when every live record was listed, so absent keys are known to be absent. */
  complete: boolean
}

export interface SectionSource {
  path: string
  keyAttribute: string
  /** Whether `q[<key>_in]` filters on the key; otherwise the section is listed whole. */
  filterable: boolean
  expand?: string[]
  /** Extra list filters, e.g. first-party rows only on a table sellers share. */
  listParams?: Record<string, string | number | boolean>
  /** Natural key of a live record; defaults to its `keyAttribute`. */
  liveKey?: (live: LiveRecord) => string
  /** Natural keys the file declares; a read-only source declares none. */
  fileKeys?: (config: SpreeConfig) => string[]
}

export function liveKeyOf(source: SectionSource, live: LiveRecord): string {
  return source.liveKey ? source.liveKey(live) : String(live[source.keyAttribute])
}

/**
 * What a run knows about the live store: the records each section listed,
 * the ones it created, and how to turn a natural key into an id.
 */
export class RunContext {
  private readonly live = new Map<string, LiveSection>()
  private readonly created = new Map<string, Map<string, LiveRecord>>()

  constructor(
    readonly client: ConfigClient,
    readonly config: SpreeConfig,
    private readonly sources: Record<string, SectionSource>,
  ) {}

  /**
   * Live records of a section. With `keys` given and the section filterable,
   * only those keys are fetched; otherwise the whole section is listed.
   * Read-only lookups (product types) are sources too, so a reference to
   * one resolves the same way.
   */
  async load(section: string, keys?: string[]): Promise<LiveSection> {
    const source = this.sources[section]
    if (!source) throw new Error(`unknown section ${section}`)
    const cached = this.live.get(section)
    if (cached?.complete) return cached
    if (cached && keys?.every((key) => cached.byKey.has(key))) return cached

    const params = {
      ...(source.listParams ?? {}),
      ...(source.expand ? { expand: source.expand.join(',') } : {}),
    }
    const partial = Boolean(keys && source.filterable)
    const records = partial
      ? await listByKeys(this.client, source.path, source.keyAttribute, keys as string[], params)
      : await listAll(this.client, source.path, params)

    const byKey = cached?.byKey ?? new Map<string, LiveRecord[]>()
    for (const record of records) {
      const key = liveKeyOf(source, record)
      const existing = byKey.get(key) ?? []
      if (!existing.some((candidate) => candidate.id === record.id)) existing.push(record)
      byKey.set(key, existing)
    }
    // A filtered fetch marks the asked-for keys as known, even when absent.
    for (const key of keys ?? []) if (!byKey.has(key)) byKey.set(key, [])
    const loaded = { byKey, complete: !partial }
    this.live.set(section, loaded)
    return loaded
  }

  /** The one live record under a key, or null when there is none. */
  async find(section: string, key: string, path = section): Promise<LiveRecord | null> {
    const fresh = this.created.get(section)?.get(key)
    if (fresh) return fresh
    const loaded = await this.load(section, [key])
    const matches = loaded.byKey.get(key) ?? []
    if (matches.length > 1) {
      throw new ConfigError(
        `${matches.length} live ${section} share the key "${key}"; rename them before deploying`,
        path,
      )
    }
    return matches[0] ?? null
  }

  private readonly declared = new Map<string, Set<string>>()

  /** Whether the file declares a record under this section and key. */
  declares(section: string, key: string): boolean {
    let keys = this.declared.get(section)
    if (!keys) {
      keys = new Set(this.sources[section]?.fileKeys?.(this.config) ?? [])
      this.declared.set(section, keys)
    }
    return keys.has(key)
  }

  /**
   * The id a natural key resolves to: a live record's id, or a pending
   * reference when the file declares the record and the run will create it.
   */
  async ref(section: string, key: string, path: string): Promise<string | PendingRef> {
    const live = await this.find(section, key, path)
    if (live) return live.id
    if (this.declares(section, key)) return new PendingRef(section, key)
    throw new DanglingReferenceError(section, key, path)
  }

  /** A created or updated record, so later references and reruns see it. */
  register(section: string, key: string, record: LiveRecord): void {
    const bucket = this.created.get(section) ?? new Map<string, LiveRecord>()
    bucket.set(key, record)
    this.created.set(section, bucket)
    const loaded = this.live.get(section)
    if (loaded) loaded.byKey.set(key, [record])
  }

  /** Replaces every pending reference in a payload with the id it now has. */
  materialize<T>(payload: T): T {
    if (payload instanceof PendingRef) {
      const record = this.created.get(payload.section)?.get(payload.key)
      if (!record) {
        throw new Error(
          `${payload.section} "${payload.key}" was not created, so it cannot be referenced`,
        )
      }
      return record.id as T
    }
    if (Array.isArray(payload)) return payload.map((item) => this.materialize(item)) as T
    if (payload && typeof payload === 'object') {
      return Object.fromEntries(
        Object.entries(payload).map(([key, value]) => [key, this.materialize(value)]),
      ) as T
    }
    return payload
  }

  /** Natural key of a live record by id, for turning ids back into keys. */
  async keyOf(section: string, id: string): Promise<string | null> {
    const loaded = await this.load(section)
    for (const [key, records] of loaded.byKey) {
      if (records.some((record) => record.id === id)) return key
    }
    return null
  }
}
