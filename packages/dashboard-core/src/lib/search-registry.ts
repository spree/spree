import type { ReactNode } from 'react'
import { useSyncExternalStore } from 'react'
import type { SubjectName } from './permissions'

/**
 * Registry for the command-palette global resource search. Mirrors
 * `nav-registry.ts`: a module-singleton populated at app boot by side-effect
 * modules (see `@/search/default` in the dashboard app), read reactively via
 * `useSearchEntries`.
 *
 * Each entry teaches the palette how to search one resource type: how to fetch
 * matches, how to render a result row, and where a row navigates. Adding a new
 * searchable resource is one `searchRegistry.add(...)` call — no edits to the
 * palette component or the search hook. Plugins extend search the same way they
 * extend the nav.
 *
 * The result type is erased at the registry boundary (`unknown`): the palette
 * never inspects a result directly, it only hands each one back to the entry's
 * own `renderRow`/`getRoute`/`getKey`, which are typed against the resource.
 * Use `defineSearchEntry` to keep that wiring type-safe at the call site.
 */

export interface SearchResultRow {
  /** cmdk value — must be unique across the whole list; prefix with the entry key. */
  value: string
  /** Row contents rendered inside the `CommandItem`. */
  content: ReactNode
}

export interface SearchEntry<T = unknown> {
  /** Stable identifier — register/remove key, React key, and result-value prefix. */
  key: string
  /** i18n key for the group heading (resolved with `t` at render time). */
  headingKey: string
  /** CanCanCan subject gating both the query and the rendered group. Omit for always-on. */
  subject?: SubjectName
  /**
   * Lower numbers render first. Built-ins use 100/200/300… so plugins can slot
   * between them. Also orders the parallel queries, purely cosmetically.
   */
  position?: number
  /**
   * Fetch up to `limit` matches for `query`. Returns the raw resource records;
   * the palette passes each back through this entry's `renderRow`/`getRoute`.
   */
  fetch: (query: string, limit: number) => Promise<T[]>
  /** Stable React key for a single result (typically the prefixed `id`). */
  getKey: (item: T) => string
  /** Render one result row's inner content (icon/thumbnail + label + badges). */
  renderRow: (item: T) => ReactNode
  /** Resolve the destination for a clicked result, given the active store. */
  getRoute: (item: T, storeId: string) => { to: string }
}

interface SearchMutator {
  /** Register an entry. Throws if the key is already registered. */
  add<T>(entry: SearchEntry<T>): void
  /** Remove an entry by key. No-op when missing. */
  remove(key: string): void
  /** Patch an existing entry. Throws if the key is missing. */
  update<T>(key: string, patch: Partial<Omit<SearchEntry<T>, 'key'>>): void
}

const entries: SearchEntry[] = []
const listeners = new Set<() => void>()
let snapshotCache: SearchEntry[] | null = null

function notify() {
  snapshotCache = null
  for (const l of listeners) l()
}

export const searchRegistry: SearchMutator = {
  add(entry) {
    if (entries.some((e) => e.key === entry.key)) {
      throw new Error(
        `Search entry "${entry.key}" already registered. Use searchRegistry.update().`,
      )
    }
    entries.push(entry as SearchEntry)
    notify()
  },
  remove(key) {
    const i = entries.findIndex((e) => e.key === key)
    if (i === -1) return
    entries.splice(i, 1)
    notify()
  },
  update(key, patch) {
    const e = entries.find((x) => x.key === key)
    if (!e) throw new Error(`Search entry "${key}" not found.`)
    Object.assign(e, patch)
    notify()
  },
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener)
  return () => {
    listeners.delete(listener)
  }
}

function getSnapshot(): SearchEntry[] {
  if (!snapshotCache) {
    snapshotCache = [...entries].sort((a, b) => (a.position ?? 100) - (b.position ?? 100))
  }
  return snapshotCache
}

/** Reactively read the sorted search entries. Re-renders on registry mutation. */
export function useSearchEntries(): SearchEntry[] {
  return useSyncExternalStore(subscribe, getSnapshot, getSnapshot)
}

/**
 * Identity helper that infers `T` from `fetch`/`getKey`/`renderRow`/`getRoute`
 * so the callbacks are typed against the resource at the registration site,
 * while the registry stores the erased `SearchEntry`.
 */
export function defineSearchEntry<T>(entry: SearchEntry<T>): SearchEntry<T> {
  return entry
}

/** Test-only: clear the registry. */
export function __resetSearchRegistry(): void {
  entries.length = 0
  notify()
}
