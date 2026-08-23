import type { LucideIcon } from 'lucide-react'
import { type ComponentType, useSyncExternalStore } from 'react'
import type { ActionName, SubjectName } from './permissions'

// ============================================================================
// Types
// ============================================================================

export type NavSection = 'main' | 'bottom'

/** Ambient context passed to `NavEntry.if` — mirrors `SlotAmbientContext`. */
export interface NavVisibilityContext {
  permissions?: unknown
  store?: unknown
  user?: unknown
}

export interface NavEntry {
  /** Stable identifier — used for register/remove/update and as the React key. */
  key: string
  /**
   * Visible label. Built-in entries should prefer `labelKey` so the sidebar
   * re-renders on language change; a literal `label` is resolved once at
   * registration and then frozen. Plugins without translation bundles of their
   * own can still pass a literal.
   */
  label?: string
  /** i18n key passed to `t(...)` at render time. Takes precedence over `label`. */
  labelKey?: string
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
  /**
   * Action checked against `subject`. Defaults to `'read'`. Entries for pages
   * that only exist to *change* something should declare `'update'` — every
   * staff member can read the store record for shell data, so a read gate on
   * `Spree::Store` shows the item to everyone.
   */
  action?: ActionName
  /**
   * State-based visibility gate evaluated at render (top-level entries only),
   * e.g. hide Getting Started once the store's setup tasks are all done.
   * Combines with `subject` — both must pass.
   */
  if?: (ctx: NavVisibilityContext) => boolean
  /**
   * Rendered after the label (e.g. a count). A component — not an element —
   * so it can call hooks like useStore and return null to hide itself.
   */
  badge?: ComponentType
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
  /**
   * Append a child under an existing top-level entry (e.g. nest a plugin page
   * under the built-in `products` menu). Preserves the parent's existing
   * children — unlike `update(parent, { children })`, which replaces them.
   * Throws if the parent is missing or the child key already exists there.
   */
  addChild(parentKey: string, child: NavEntry): void
  /** Remove a child by key from a parent. No-op when either is absent. */
  removeChild(parentKey: string, childKey: string): void
  /** Patch a child of `parentKey`. Throws if the parent or child is missing. */
  updateChild(parentKey: string, childKey: string, patch: Partial<Omit<NavEntry, 'key'>>): void
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

/**
 * The label shape both nav registries share: a translation key, or a literal
 * for plugins that ship no translation bundle of their own.
 */
export interface LabelledEntry {
  key: string
  label?: string
  labelKey?: string
}

/** Throws unless the entry can produce a visible label. */
export function ensureLabelled(entry: LabelledEntry, kind = 'Nav entry') {
  if (!entry.label && !entry.labelKey) {
    throw new Error(`${kind} "${entry.key}" must define either "label" or "labelKey".`)
  }
}

/**
 * Resolve an entry's visible label. Prefer this over inlining the ternary —
 * the fallbacks used to disagree between call sites, so an entry registered
 * with neither field rendered blank on one surface and its key on another.
 *
 * @param entry Entry from either nav registry.
 * @param t Translation function used to resolve `labelKey`.
 * @returns The translated label, the literal, or the key as a last resort.
 */
export function resolveNavLabel(entry: LabelledEntry, t: (key: string) => string): string {
  return entry.labelKey ? t(entry.labelKey) : (entry.label ?? entry.key)
}

/** Same contract as `resolveNavLabel` for the optional description pair. */
export function resolveNavDescription(
  entry: { description?: string; descriptionKey?: string },
  t: (key: string) => string,
): string | undefined {
  return entry.descriptionKey ? t(entry.descriptionKey) : entry.description
}

/**
 * Whether `pathname` is `url` or sits beneath it. The `/` boundary matters:
 * a bare `startsWith` makes `/orders` match `/orders-archive`.
 */
export function isPathWithin(pathname: string, url: string): boolean {
  return pathname === url || pathname.startsWith(`${url}/`)
}

// ============================================================================
// Public API
// ============================================================================

export const nav: NavMutator = {
  add(entry) {
    ensureUniqueKey(entry.key)
    ensureLabelled(entry)
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
    // Re-validate the merged entry — the patch could remove both label fields.
    ensureLabelled(e)
    notify()
  },
  insertBefore(targetKey, entry) {
    const i = findIndex(targetKey)
    if (i === -1) throw new Error(`Nav entry "${targetKey}" not found.`)
    ensureUniqueKey(entry.key)
    ensureLabelled(entry)
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
    ensureLabelled(entry)
    const target = entries[i]
    const adjusted: NavEntry = {
      ...entry,
      position: entry.position ?? (target.position ?? 100) + 1,
    }
    entries.splice(i + 1, 0, adjusted)
    notify()
  },
  addChild(parentKey, child) {
    const parent = requireEntry(parentKey)
    ensureLabelled(child)
    if (parent.children?.some((c) => c.key === child.key)) {
      throw new Error(
        `Nav child "${child.key}" already exists under "${parentKey}". Use nav.updateChild().`,
      )
    }
    parent.children = [...(parent.children ?? []), child]
    notify()
  },
  removeChild(parentKey, childKey) {
    const parent = entries.find((e) => e.key === parentKey)
    if (!parent?.children) return
    const next = parent.children.filter((c) => c.key !== childKey)
    if (next.length === parent.children.length) return
    parent.children = next
    notify()
  },
  updateChild(parentKey, childKey, patch) {
    const parent = requireEntry(parentKey)
    const idx = parent.children?.findIndex((c) => c.key === childKey) ?? -1
    if (idx === -1 || !parent.children) {
      throw new Error(`Nav child "${childKey}" not found under "${parentKey}".`)
    }
    // Replace both the child and the array so the patched entry gets a fresh
    // reference in the next snapshot — in-place mutation would defeat any
    // reference-equality memoization on the item component.
    const next = [...parent.children]
    next[idx] = { ...next[idx], ...patch }
    ensureLabelled(next[idx])
    parent.children = next
    notify()
  },
}

function requireEntry(key: string): NavEntry {
  const entry = entries.find((e) => e.key === key)
  if (!entry) throw new Error(`Nav entry "${key}" not found.`)
  return entry
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

/** Test-only: raw entries in registration order (unsorted, unsectioned). */
export function __getNavEntries(): readonly NavEntry[] {
  return entries
}
