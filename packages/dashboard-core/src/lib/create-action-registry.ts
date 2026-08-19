import type { LucideIcon } from 'lucide-react'
import { useSyncExternalStore } from 'react'
import type { SubjectName } from './permissions'

/**
 * Registry for the command palette's create actions — the rows that turn
 * "add product" or "new order" into a jump to the matching create page.
 *
 * Mirrors `search-registry.ts` and `nav-registry.ts`: a module-singleton
 * populated at app boot by side-effect modules, read reactively via
 * `useCreateActions`. Plugins register their own create pages the same way.
 *
 * Matching is a concern of `matchCreateActions` below, not of the entry: an
 * entry only declares what it is called and where it goes.
 */

export interface CreateActionEntry {
  /** Stable identifier — register/remove key, React key, and result-value prefix. */
  key: string
  /**
   * i18n key for the singular resource noun, as the merchant would type it
   * ("Product", "Customer"). Resolved with `t` at match time so typing the
   * noun works in the merchant's own language.
   */
  labelKey: string
  /**
   * Extra i18n keys for words that should also match this action — plurals,
   * synonyms, and abbreviations ("SKU" for a product). Optional.
   */
  aliasKeys?: string[]
  /** Row icon. */
  icon?: LucideIcon
  /** CanCanCan subject gating the action. Checked with `create`, not `read`. */
  subject?: SubjectName
  /** Lower numbers render first among equally-good matches. */
  position?: number
  /**
   * Destination, given the active store. Either a dedicated create route
   * (`/${storeId}/products/new`) or an index page with the create sheet open
   * (`/${storeId}/customers?new=true`).
   */
  getRoute: (storeId: string) => { to: string; search?: Record<string, unknown> }
}

interface CreateActionMutator {
  /** Register an action. Throws if the key is already registered. */
  add(entry: CreateActionEntry): void
  /** Remove an action by key. No-op when missing. */
  remove(key: string): void
  /** Patch an existing action. Throws if the key is missing. */
  update(key: string, patch: Partial<Omit<CreateActionEntry, 'key'>>): void
}

const entries: CreateActionEntry[] = []
const listeners = new Set<() => void>()
let snapshotCache: CreateActionEntry[] | null = null

function notify() {
  snapshotCache = null
  for (const l of listeners) l()
}

export const createActionRegistry: CreateActionMutator = {
  add(entry) {
    if (entries.some((e) => e.key === entry.key)) {
      throw new Error(
        `Create action "${entry.key}" already registered. Use createActionRegistry.update().`,
      )
    }
    entries.push(entry)
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
    if (!e) throw new Error(`Create action "${key}" not found.`)
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

function getSnapshot(): CreateActionEntry[] {
  if (!snapshotCache) {
    snapshotCache = [...entries].sort((a, b) => (a.position ?? 100) - (b.position ?? 100))
  }
  return snapshotCache
}

/** Reactively read the sorted create actions. Re-renders on registry mutation. */
export function useCreateActions(): CreateActionEntry[] {
  return useSyncExternalStore(subscribe, getSnapshot, getSnapshot)
}

/** Test-only: clear the registry. */
export function __resetCreateActionRegistry(): void {
  entries.length = 0
  notify()
}

// ---------------------------------------------------------------------------
// Matching
// ---------------------------------------------------------------------------

/**
 * i18n key holding the create verbs for the active language, as a
 * comma-separated list ("add,new,create"). A list rather than one word because
 * merchants reach for whichever verb comes to mind, and several languages have
 * more than one natural phrasing.
 */
export const CREATE_VERBS_KEY = 'admin.components.command_palette.create.verbs'

export interface CreateActionMatch {
  entry: CreateActionEntry
  /** The resolved noun that matched, for rendering the row's label. */
  noun: string
  /** Lower sorts first: an exact noun match beats a prefix beats a substring. */
  rank: number
}

/** Fold case and strip accents so "Rückgabe" matches "ruckgabe". */
function normalize(value: string): string {
  return value
    .toLowerCase()
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .trim()
}

/**
 * Turn a raw palette query into the create actions it names.
 *
 * Matches "<verb> <noun>" in either order, since languages disagree on which
 * comes first — English puts the verb first ("add product"), while a merchant
 * typing Polish or German may not. A bare verb ("new") lists everything
 * creatable, which doubles as discovery of what this dashboard can create.
 *
 * Returns an empty array when the query names no verb, so ordinary searches are
 * unaffected.
 */
export function matchCreateActions({
  query,
  entries,
  t,
}: {
  query: string
  entries: CreateActionEntry[]
  t: (key: string) => string
}): CreateActionMatch[] {
  const words = normalize(query).split(/\s+/).filter(Boolean)
  if (words.length === 0) return []

  const verbs = new Set(
    t(CREATE_VERBS_KEY)
      .split(',')
      .map((verb) => normalize(verb))
      .filter(Boolean),
  )

  // The verb may lead or trail; strip whichever end carries it and treat the
  // rest as the noun. Checking the last word only when the first didn't match
  // keeps "add" + "add-on"-style nouns unambiguous.
  let rest: string[]
  if (verbs.has(words[0])) {
    rest = words.slice(1)
  } else if (words.length > 1 && verbs.has(words[words.length - 1])) {
    rest = words.slice(0, -1)
  } else {
    return []
  }

  const noun = rest.join(' ')
  const matches: CreateActionMatch[] = []

  for (const entry of entries) {
    const labels = [entry.labelKey, ...(entry.aliasKeys ?? [])].map((key) => t(key))
    let best: { rank: number; noun: string } | null = null

    for (const label of labels) {
      const candidate = normalize(label)
      // A bare verb lists everything; otherwise rank by how squarely the typed
      // noun lands on this label.
      const rank = !noun
        ? 3
        : candidate === noun
          ? 0
          : candidate.startsWith(noun)
            ? 1
            : candidate.includes(noun)
              ? 2
              : -1
      if (rank === -1) continue
      // Always report the primary label, so a row found via an alias still
      // reads as the resource's real name.
      if (!best || rank < best.rank) best = { rank, noun: labels[0] }
    }

    if (best) matches.push({ entry, noun: best.noun, rank: best.rank })
  }

  return matches.sort(
    (a, b) => a.rank - b.rank || (a.entry.position ?? 100) - (b.entry.position ?? 100),
  )
}
