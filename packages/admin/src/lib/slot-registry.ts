import type { ComponentType } from 'react'
import { useSyncExternalStore } from 'react'

// ============================================================================
// Types
// ============================================================================

/**
 * Ambient context every slot receives, on top of slot-specific context.
 * Populated by SlotProvider (see slot.tsx). Plugins reading these don't need
 * to import auth/permission hooks — the slot machinery passes them through.
 */
export interface SlotAmbientContext {
  permissions?: unknown
  store?: unknown
  user?: unknown
}

export interface SlotEntry<TContext = unknown> {
  /** Unique within a slot. Required for removeSlot/updateSlot. */
  id: string
  component: ComponentType<TContext & SlotAmbientContext>
  /** Lower numbers render first. Built-ins use 100/200/300 to leave gaps. */
  position?: number
  /** Visibility predicate. Receives the merged context. */
  if?: (ctx: TContext & SlotAmbientContext) => boolean
}

// ============================================================================
// Registry — module-singleton keyed by slot name
// ============================================================================

const registry = new Map<string, SlotEntry[]>()
const listeners = new Set<() => void>()

function notify() {
  for (const listener of listeners) listener()
}

function subscribe(listener: () => void) {
  listeners.add(listener)
  return () => {
    listeners.delete(listener)
  }
}

function getSnapshot(name: string): readonly SlotEntry[] {
  return registry.get(name) ?? EMPTY
}

const EMPTY: readonly SlotEntry[] = Object.freeze([])

// ============================================================================
// Public API
// ============================================================================

export function registerSlot<TContext = unknown>(name: string, entry: SlotEntry<TContext>): void {
  const list = registry.get(name) ?? []
  if (list.some((e) => e.id === entry.id)) {
    throw new Error(
      `Slot "${name}" already has an entry with id "${entry.id}". Use updateSlot() instead.`,
    )
  }
  registry.set(name, [...list, entry as SlotEntry])
  notify()
}

export function removeSlot(name: string, id: string): void {
  const list = registry.get(name)
  if (!list) return
  const next = list.filter((e) => e.id !== id)
  if (next.length === list.length) return
  registry.set(name, next)
  notify()
}

export function updateSlot<TContext = unknown>(
  name: string,
  id: string,
  patch: Partial<Omit<SlotEntry<TContext>, 'id'>>,
): void {
  const list = registry.get(name)
  const entry = list?.find((e) => e.id === id)
  if (!list || !entry) {
    throw new Error(`Slot entry "${name}#${id}" not found.`)
  }
  registry.set(
    name,
    list.map((e) => (e.id === id ? ({ ...e, ...patch } as SlotEntry) : e)),
  )
  notify()
}

/**
 * Subscribe to a slot's entries. Re-renders when entries are added/removed/updated
 * so plugins registered after first render still appear.
 *
 * Returned entries are sorted by position (default 100) and stable within ties.
 * Filtering by `if` happens at render time inside <Slot> — the hook returns the
 * full registered list so the caller can decide how to combine context.
 */
export function useSlotEntries(name: string): readonly SlotEntry[] {
  const entries = useSyncExternalStore(
    subscribe,
    () => getSnapshot(name),
    () => getSnapshot(name),
  )
  // Sort by position (stable). Returned array is fresh; safe to reference in render.
  return [...entries].sort((a, b) => (a.position ?? 100) - (b.position ?? 100))
}

/** Test-only: clear all registered slots. Not exported from the package index. */
export function __resetSlotRegistry(): void {
  registry.clear()
  notify()
}
