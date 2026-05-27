import type { LucideIcon } from 'lucide-react'
import { useSyncExternalStore } from 'react'
import type { SubjectName } from '@/lib/permissions'

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
  /** Visible label. */
  label: string
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
  /** When true, the page is disabled in the sidebar with a "Soon" badge. */
  comingSoon?: boolean
}

export interface SettingsNavGroup {
  /** Group identifier referenced by entries. */
  key: string
  /** Visible header label. */
  label: string
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
    Object.assign(e, patch)
    notify()
  },
  addGroup(group) {
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

/** Test-only: clear the registry. */
export function __resetSettingsNavRegistry(): void {
  entries.length = 0
  groups.length = 0
  notify()
}
