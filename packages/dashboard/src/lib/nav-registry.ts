import type { LucideIcon } from 'lucide-react'
import { useSyncExternalStore } from 'react'
import type { SubjectName } from '@/lib/permissions'

// ============================================================================
// Types
// ============================================================================

export type NavSection = 'main' | 'bottom'

export interface NavEntry {
  /** Stable identifier — used for register/remove/update and as the React key. */
  key: string
  /** Visible label. */
  label: string
  /**
   * Path template, prefixed with `/$storeId` at render time. Pass paths like
   * `'/orders'`, NOT `/store_abc/orders`. The leading slash is required.
   */
  path: string
  /** Sidebar icon (top-level entries only — subitems don't render icons). */
  icon?: LucideIcon
  /** Section. Defaults to `'main'`. `'bottom'` pins to the sidebar footer. */
  section?: NavSection
  /** Lower numbers render first. Built-ins use 100/200/300… so plugins can slot in between. */
  position?: number
  /** CanCanCan subject required to see this item. Omit for always-visible. */
  subject?: SubjectName
  /** Nested children. Children inherit nothing — they declare their own subject + position. */
  children?: NavEntry[]
}

interface NavMutator {
  add(entry: NavEntry): void
  remove(key: string): void
  update(key: string, patch: Partial<Omit<NavEntry, 'key'>>): void
  /** Insert a new entry immediately before `targetKey`. Throws if the target is missing. */
  insertBefore(targetKey: string, entry: NavEntry): void
  /** Insert a new entry immediately after `targetKey`. Throws if the target is missing. */
  insertAfter(targetKey: string, entry: NavEntry): void
}

// ============================================================================
// Registry — module-singleton
// ============================================================================

const entries: NavEntry[] = []
const listeners = new Set<() => void>()
let snapshotCache: { main: NavEntry[]; bottom: NavEntry[] } | null = null

function notify() {
  snapshotCache = null
  for (const l of listeners) l()
}

function findIndex(key: string): number {
  return entries.findIndex((e) => e.key === key)
}

function ensureUniqueKey(key: string) {
  if (entries.some((e) => e.key === key)) {
    throw new Error(`Nav entry "${key}" already registered. Use nav.update() instead.`)
  }
}

// ============================================================================
// Public API
// ============================================================================

export const nav: NavMutator = {
  add(entry) {
    ensureUniqueKey(entry.key)
    entries.push(entry)
    notify()
  },
  remove(key) {
    const i = findIndex(key)
    if (i === -1) return
    entries.splice(i, 1)
    notify()
  },
  update(key, patch) {
    const e = entries.find((x) => x.key === key)
    if (!e) throw new Error(`Nav entry "${key}" not found.`)
    Object.assign(e, patch)
    notify()
  },
  insertBefore(targetKey, entry) {
    const i = findIndex(targetKey)
    if (i === -1) throw new Error(`Nav entry "${targetKey}" not found.`)
    ensureUniqueKey(entry.key)
    // Inherit target's position so the relative order survives `getNavEntries`'s sort.
    const target = entries[i]
    const adjusted: NavEntry = {
      ...entry,
      position: entry.position ?? (target.position ?? 100) - 1,
    }
    entries.splice(i, 0, adjusted)
    notify()
  },
  insertAfter(targetKey, entry) {
    const i = findIndex(targetKey)
    if (i === -1) throw new Error(`Nav entry "${targetKey}" not found.`)
    ensureUniqueKey(entry.key)
    const target = entries[i]
    const adjusted: NavEntry = {
      ...entry,
      position: entry.position ?? (target.position ?? 100) + 1,
    }
    entries.splice(i + 1, 0, adjusted)
    notify()
  },
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener)
  return () => {
    listeners.delete(listener)
  }
}

function buildSnapshot(): { main: NavEntry[]; bottom: NavEntry[] } {
  const sortRecursively = (list: NavEntry[]): NavEntry[] =>
    [...list]
      .sort((a, b) => (a.position ?? 100) - (b.position ?? 100))
      .map((e) => (e.children ? { ...e, children: sortRecursively(e.children) } : e))

  return {
    main: sortRecursively(entries.filter((e) => (e.section ?? 'main') === 'main')),
    bottom: sortRecursively(entries.filter((e) => e.section === 'bottom')),
  }
}

function getSnapshot() {
  if (!snapshotCache) snapshotCache = buildSnapshot()
  return snapshotCache
}

/**
 * Subscribe to nav-registry updates and read the sorted entries. Mirrors
 * `useSlotEntries` from slot-registry.ts. Re-renders only when the registry
 * is mutated; navigations don't trigger updates.
 */
export function useNavEntries() {
  return useSyncExternalStore(subscribe, getSnapshot, getSnapshot)
}

/** Test-only: clear the registry. Not exported from the package index. */
export function __resetNavRegistry(): void {
  entries.length = 0
  notify()
}
