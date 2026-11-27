import type { Order, OrderActivity } from '@spree/admin-sdk'
import type { ComponentType } from 'react'
import { useSyncExternalStore } from 'react'

/**
 * How the order timeline shows each kind of entry. Mirrors `search-registry.ts`:
 * a module singleton the dashboard fills at boot (`@/timeline/default`), read
 * reactively by the timeline.
 *
 * A kind is the event that recorded the entry (`payment.completed`) or
 * `comment`. A plugin that registers its own kind on the server shows it by
 * registering a renderer here; a kind with no renderer still gets a plain
 * entry naming the kind.
 */
export interface ActivityProps {
  activity: OrderActivity
  /** The order the entry belongs to, for its currency and records. */
  order: Order
}

export interface ActivityKind {
  kind: string
  icon?: ComponentType<{ className?: string }>
  /** One sentence saying what happened. */
  Summary: ComponentType<ActivityProps>
  /** The Summary already names who did it, so the actor is not added after it. */
  namesActor?: boolean
  /** More to show under the sentence, behind a toggle, when the entry has it. */
  Details?: ComponentType<ActivityProps>
}

interface ActivityMutator {
  /** Register a kind, replacing any renderer it had, so a plugin can restyle a built-in. */
  register(kind: ActivityKind): void
  /** Remove a kind. No-op when missing. */
  remove(kind: string): void
}

const kinds = new Map<string, ActivityKind>()
const listeners = new Set<() => void>()
let snapshot: ReadonlyMap<string, ActivityKind> = new Map()

function notify() {
  snapshot = new Map(kinds)
  for (const listener of listeners) listener()
}

export const activityRegistry: ActivityMutator = {
  register(kind) {
    kinds.set(kind.kind, kind)
    notify()
  },
  remove(kind) {
    if (kinds.delete(kind)) notify()
  },
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener)
  return () => {
    listeners.delete(listener)
  }
}

function getSnapshot(): ReadonlyMap<string, ActivityKind> {
  return snapshot
}

/** Reactively read the registered kinds, keyed by kind. */
export function useActivityKinds(): ReadonlyMap<string, ActivityKind> {
  return useSyncExternalStore(subscribe, getSnapshot, getSnapshot)
}

/** Test-only: clear the registry. */
export function __resetActivityRegistry(): void {
  kinds.clear()
  notify()
}
