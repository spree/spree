import type { LucideIcon } from 'lucide-react'
import { useSyncExternalStore } from 'react'
import { ensureLabelled, resolveNavDescription, resolveNavLabel } from './nav-registry'
import type { ActionName, SubjectName } from './permissions'

/**
 * Registry for the settings sub-shell sidebar. Mirrors `nav-registry.ts` but
 * adds a `group` key so entries cluster under labelled section headers
 * (Store · Localization · Team & Access · Developer …).
 *
 * Plugins extend the settings nav by importing `settingsNav` and calling
 * `settingsNav.add(...)` from a side-effect module loaded at app boot.
 */

export interface SettingsNavEntry {
  /** Stable identifier — used for register/remove/update and as the React key. */
  key: string
  /**
   * Visible label. Either `label` (literal) or `labelKey` (i18n key) must be
   * set; built-in entries use `labelKey` so the sidebar re-renders on
   * language change. Plugins can use either.
   */
  label?: string
  /** i18n key passed to `t(...)` at render time. Takes precedence over `label`. */
  labelKey?: string
  /**
   * One-line summary of what the page is for. Shown on the settings landing
   * page under the entry's label; the sidebar ignores it.
   */
  description?: string
  /** i18n key for `description`, resolved at render. Takes precedence over it. */
  descriptionKey?: string
  /**
   * Extra terms that match this entry in settings search, beyond its label.
   * Merchants search for the word they know ("VAT", "SKU", "CORS") rather than
   * the page's name, so list those synonyms here.
   */
  keywords?: string[]
  /**
   * Path template, prefixed with `/$storeId/settings` at render time. Pass paths
   * like `'/general'` or `'/staff'`, NOT `/store_abc/settings/general`. The
   * leading slash is required.
   */
  path: string
  /** Icon shown next to the label. */
  icon?: LucideIcon
  /** Group identifier — entries with the same group cluster under one header. */
  group: string
  /** Position within the group. Lower numbers render first. Defaults to 100. */
  position?: number
  /** CanCanCan subject required to see this item. Omit for always-visible. */
  subject?: SubjectName
  /**
   * Action checked against `subject`. Defaults to `'read'`. Settings pages
   * that only exist to *change* something (store settings, emails) should
   * declare `'update'` — every staff member can read the store record for
   * shell data, so a read check would show them a page they cannot use.
   */
  action?: ActionName
  /** When true, the page is disabled in the sidebar with a "Soon" badge. */
  comingSoon?: boolean
}

export interface SettingsNavGroup {
  /** Group identifier referenced by entries. */
  key: string
  /** Visible header label. Mirrors `SettingsNavEntry.label` — pair with `labelKey` when localising. */
  label?: string
  /** i18n key passed to `t(...)` at render time. Takes precedence over `label`. */
  labelKey?: string
  /** Group ordering. Lower numbers render first. Defaults to 100. */
  position?: number
}

interface SettingsNavMutator {
  /** Register an entry. Throws if the key is already registered. */
  add(entry: SettingsNavEntry): void
  /** Remove an entry by key. No-op when missing. */
  remove(key: string): void
  /** Patch an existing entry. Throws if the key is missing. */
  update(key: string, patch: Partial<Omit<SettingsNavEntry, 'key'>>): void
  /** Register a group. Throws if the key is already registered. */
  addGroup(group: SettingsNavGroup): void
}

const entries: SettingsNavEntry[] = []
const groups: SettingsNavGroup[] = []
const listeners = new Set<() => void>()
let snapshotCache: SettingsNavSnapshot | null = null

export interface SettingsNavSnapshot {
  /** Groups, sorted by `position`, each with their entries (also sorted). */
  groups: Array<{ group: SettingsNavGroup; entries: SettingsNavEntry[] }>
  /** Flat list of every entry, sorted by group position then entry position. */
  all: SettingsNavEntry[]
}

function notify() {
  snapshotCache = null
  for (const l of listeners) l()
}

export const settingsNav: SettingsNavMutator = {
  add(entry) {
    ensureLabelled(entry, 'Settings nav entry')
    if (entries.some((e) => e.key === entry.key)) {
      throw new Error(`Settings nav entry "${entry.key}" already registered.`)
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
    if (!e) throw new Error(`Settings nav entry "${key}" not found.`)
    // Validate a copy before touching the stored entry: a patch that removes
    // both label fields must leave the registry as it was, not half-applied.
    ensureLabelled({ ...e, ...patch }, 'Settings nav entry')
    Object.assign(e, patch)
    notify()
  },
  addGroup(group) {
    ensureLabelled(group, 'Settings nav group')
    if (groups.some((g) => g.key === group.key)) {
      throw new Error(`Settings nav group "${group.key}" already registered.`)
    }
    groups.push(group)
    notify()
  },
}

function buildSnapshot(): SettingsNavSnapshot {
  const sortedGroups = [...groups].sort((a, b) => (a.position ?? 100) - (b.position ?? 100))
  const grouped = sortedGroups
    .map((group) => ({
      group,
      entries: entries
        .filter((e) => e.group === group.key)
        .sort((a, b) => (a.position ?? 100) - (b.position ?? 100)),
    }))
    .filter((g) => g.entries.length > 0)
  return {
    groups: grouped,
    all: grouped.flatMap((g) => g.entries),
  }
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener)
  return () => {
    listeners.delete(listener)
  }
}

function getSnapshot() {
  if (!snapshotCache) snapshotCache = buildSnapshot()
  return snapshotCache
}

export function useSettingsNav() {
  return useSyncExternalStore(subscribe, getSnapshot, getSnapshot)
}

/**
 * Whether a settings entry matches a search term. Label, description and the
 * entry's own `keywords` all count, so the word a merchant knows ("VAT",
 * "CORS") reaches the page named something else. Shared by the settings
 * sidebar and the settings landing page so both filter identically.
 *
 * @param entry Entry to test.
 * @param term Search text; matching is case-insensitive and ignores surrounding space.
 * @param t Translation function used to resolve `labelKey`/`descriptionKey`.
 * @returns True when the entry matches, or when the term is blank.
 */
export function settingsEntryMatches(
  entry: SettingsNavEntry,
  term: string,
  t: (key: string) => string,
): boolean {
  const needle = term.trim().toLowerCase()
  if (!needle) return true

  const haystack = [
    resolveNavLabel(entry, t),
    resolveNavDescription(entry, t),
    ...(entry.keywords ?? []),
  ]
  return haystack.some((value) => value?.toLowerCase().includes(needle))
}

/**
 * Drop entries the current staff member cannot reach. Exported because the
 * sidebar and the settings landing page must agree on what a role can see —
 * a private copy on either surface is how one starts showing a card the other
 * hides.
 */
export function filterSettingsByPermissions(
  snapshot: SettingsNavSnapshot,
  permissions: { can: (action: string, subject: string) => boolean },
): SettingsNavSnapshot {
  return regroup(snapshot, (entry) =>
    !entry.subject ? true : permissions.can(entry.action ?? 'read', entry.subject),
  )
}

/** Narrow the nav to entries matching the merchant's search. */
export function filterSettingsByQuery(
  snapshot: SettingsNavSnapshot,
  query: string,
  t: (key: string) => string,
): SettingsNavSnapshot {
  return regroup(snapshot, (entry) => settingsEntryMatches(entry, query, t))
}

/** Rebuild a snapshot from the entries passing `keep`, dropping emptied groups. */
function regroup(
  snapshot: SettingsNavSnapshot,
  keep: (entry: SettingsNavEntry) => boolean,
): SettingsNavSnapshot {
  const groups = snapshot.groups
    .map(({ group, entries }) => ({ group, entries: entries.filter(keep) }))
    .filter((g) => g.entries.length > 0)
  return { groups, all: groups.flatMap((g) => g.entries) }
}

/**
 * Whether any settings entry is reachable for these permissions. The Settings
 * launcher in the primary sidebar uses this so a role with no settings
 * authority never opens an empty shell.
 */
export function hasVisibleSettingsEntries(permissions: unknown): boolean {
  const can = (permissions as { can?: (action: string, subject: string) => boolean } | undefined)
    ?.can
  if (typeof can !== 'function') return false

  return getSnapshot().all.some(
    (entry) => !entry.subject || can(entry.action ?? 'read', entry.subject),
  )
}

/** Test-only: clear the registry. */
export function __resetSettingsNavRegistry(): void {
  entries.length = 0
  groups.length = 0
  notify()
}
