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

/**
 * The create-action registry. Every mutation notifies subscribers, so a page
 * rendered through `useCreateActions` reflects it immediately — which is how a
 * plugin can register its create pages after the app has booted.
 *
 * `add` throws on a duplicate key and `update` throws on an unknown one, so a
 * plugin colliding with a built-in fails loudly instead of silently shadowing
 * it. `remove` is tolerant, letting teardown run unconditionally.
 */
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

/**
 * Scripts written without spaces between words. Restricting the unspaced verb
 * match to these keeps it from firing on space-delimited languages, where
 * "address" would otherwise read as the verb "add" plus a noun "ress".
 */
const UNSPACED_SCRIPT = /[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]/u

/**
 * Strip a leading or trailing verb from an unspaced query, returning the noun
 * that remains (`''` when the query is just the verb). Returns `null` when the
 * query carries no verb or isn't written in an unspaced script.
 */
function stripUnspacedVerb(query: string, verbs: Set<string>): string | null {
  if (!UNSPACED_SCRIPT.test(query)) return null

  // Longest first, so a verb that is a prefix of another ("新" vs "新建")
  // can't strip the shorter match and leave the rest of the verb in the noun.
  const byLength = [...verbs].sort((a, b) => b.length - a.length)

  for (const verb of byLength) {
    if (query === verb) return ''
    if (query.startsWith(verb)) return query.slice(verb.length)
    if (query.endsWith(verb)) return query.slice(0, -verb.length)
  }
  return null
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
/**
 * The create actions a query names, narrowed to those the signed-in user may
 * actually create.
 *
 * Create is gated on the `create` action rather than `read`: a user who can
 * list products but not add one should never be offered "New product". Entries
 * without a subject are ungated.
 */
export function permittedCreateActions({
  query,
  entries,
  t,
  can,
}: {
  query: string
  entries: CreateActionEntry[]
  t: (key: string) => string
  can: (action: string, subject: string) => boolean
}): CreateActionMatch[] {
  return matchCreateActions({ query, entries, t }).filter(
    ({ entry }) => !entry.subject || can('create', entry.subject),
  )
}

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
  let noun: string
  if (verbs.has(words[0])) {
    noun = words.slice(1).join(' ')
  } else if (words.length > 1 && verbs.has(words[words.length - 1])) {
    noun = words.slice(0, -1).join(' ')
  } else {
    // Languages that don't put spaces between words — Chinese, Japanese —
    // arrive as one token ("新建商品"), so word equality never matches. Fall
    // back to stripping the verb as a prefix or suffix of the whole query.
    const unspaced = stripUnspacedVerb(normalize(query), verbs)
    if (unspaced === null) return []
    noun = unspaced
  }
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
