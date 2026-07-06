// `@spree/dashboard-core/plugin` — the single import plugin authors use.
//
// A plugin's entry module calls `defineDashboardPlugin({...})` at import time;
// the dashboard app imports plugin entries in its bootstrap before the first
// render. Each registry uses `useSyncExternalStore`, so late registration
// (after the app has mounted) still re-renders consumers.
//
// Example:
//
//     import { defineDashboardPlugin } from '@spree/dashboard-core/plugin'
//     import { Card } from '@spree/dashboard-ui'
//
//     function WishlistCount({ product }: { product: { wishlist_count: number } }) {
//       return <Card>Wishlists: {product.wishlist_count}</Card>
//     }
//
//     defineDashboardPlugin({
//       nav: [
//         { key: 'wishlists', label: 'Wishlists', path: '/wishlists', position: 50 },
//       ],
//       slots: {
//         'product.form_sidebar': [
//           { id: 'wishlist-count', component: WishlistCount, position: 50 },
//         ],
//       },
//       tables: {
//         products: { add: [{ key: 'wishlist_count', label: 'Wishlists', sortable: true }] },
//       },
//       settingsNav: [
//         { key: 'wishlist-settings', label: 'Wishlists', path: '/wishlists', group: 'integrations' },
//       ],
//     })

import type { NavEntry } from './lib/nav-registry'
import { nav } from './lib/nav-registry'
import type { RouteEntry } from './lib/route-registry'
import { pluginRoutes } from './lib/route-registry'
import type { SettingsNavEntry, SettingsNavGroup } from './lib/settings-nav-registry'
import { settingsNav } from './lib/settings-nav-registry'
import type { SlotEntry } from './lib/slot-registry'
import { registerSlot } from './lib/slot-registry'
import type { ColumnDef } from './lib/table-registry'
import { tables } from './lib/table-registry'

export interface TableMutations {
  /** Columns to append to the table. Keys must not already exist. */
  add?: ColumnDef[]
  /** Column keys to remove. No-op when the column is already gone. */
  remove?: string[]
  /** Column patches keyed by column key — `{ totals: { label: 'Net total' } }`. */
  update?: Record<string, Partial<ColumnDef>>
}

export interface NavMutations {
  /** Sidebar entries to add. Each must have a unique `key`. */
  add?: NavEntry[]
  /** Entry keys to remove — built-in or plugin. No-op when already gone. */
  remove?: string[]
  /**
   * Patches keyed by entry key — reorder via `position`, rename via `label`,
   * gate via `subject`. Throws when the key isn't registered, so patch only
   * entries you know exist (built-ins register before any plugin runs).
   */
  update?: Record<string, Partial<Omit<NavEntry, 'key'>>>
  /**
   * Children to append under existing top-level entries, keyed by parent key
   * — e.g. `{ products: [{ key: 'products.brands', … }] }` nests an item in
   * the built-in Products menu. Preserves the parent's existing children.
   * Throws when the parent is missing or a child key already exists there.
   */
  addChildren?: Record<string, NavEntry[]>
}

export interface SettingsNavMutations {
  /** Settings sub-shell entries to add. */
  add?: SettingsNavEntry[]
  /** Entry keys to remove. No-op when already gone. */
  remove?: string[]
  /** Patches keyed by entry key. Throws when the key isn't registered. */
  update?: Record<string, Partial<Omit<SettingsNavEntry, 'key'>>>
}

export interface DashboardPluginConfig {
  /**
   * Sidebar entries. The array form adds entries; the object form also
   * removes or patches existing ones (built-ins included):
   *
   *     nav: {
   *       add: [{ key: 'reviews', label: 'Reviews', path: '/reviews' }],
   *       remove: ['gift-cards'],
   *       update: { products: { position: 10 } },
   *     }
   */
  nav?: NavEntry[] | NavMutations
  /** Settings sub-shell groups (defined before any entry that uses the group key). */
  settingsNavGroups?: SettingsNavGroup[]
  /** Settings sub-shell entries — array adds; object form also removes/patches. */
  settingsNav?: SettingsNavEntry[] | SettingsNavMutations
  /** Slot extensions keyed by slot name. Each entry must have a unique `id`. */
  slots?: Record<string, SlotEntry[]>
  /** Table mutations keyed by table key (see `defineTable`). */
  tables?: Record<string, TableMutations>
  /**
   * Custom routes mounted under `/$storeId/`. Each entry's `path` is relative
   * (e.g. `/brands`, `/brands/$brandId`). The dashboard's catch-all route at
   * `/$storeId/*` dispatches based on the splat — your `component` renders
   * exactly like any first-party route, including TanStack Router's
   * `useParams()` for path params.
   */
  routes?: RouteEntry[]
}

/**
 * Register all the extensions in `config` against the dashboard's registries.
 * Call it once per plugin entry module — each registry enforces uniqueness on
 * its keys, so re-running the same config (or colliding with another plugin's
 * `key`/`id`) throws with a useful message rather than double-registering.
 *
 * Plugins typically call this once from their entry module (e.g.
 * `src/index.ts`). The dashboard app imports plugin entries during bootstrap.
 *
 * @returns nothing — registries are module singletons. To unregister, call the
 *          relevant `nav.remove` / `removeSlot` / `tables.<key>.removeColumn` /
 *          `settingsNav.remove` directly.
 */
export function defineDashboardPlugin(config: DashboardPluginConfig): void {
  // Collect errors across every registry call and rethrow once at the end.
  // A duplicate nav key shouldn't stop the rest of the config (slots, tables,
  // other nav entries) from registering — plugin authors should see every
  // problem in their config at once, not whack-a-mole through reload cycles.
  // Matches the deferred-flush semantics in `table-registry.ts`.
  const errors: unknown[] = []
  const safely = <T extends unknown[]>(fn: (...args: T) => void, ...args: T) => {
    try {
      fn(...args)
    } catch (err) {
      errors.push(err)
    }
  }

  if (config.nav) {
    const m: NavMutations = Array.isArray(config.nav) ? { add: config.nav } : config.nav
    // add before addChildren so a plugin can add a parent then nest under it.
    for (const entry of m.add ?? []) safely(nav.add, entry)
    for (const [parentKey, children] of Object.entries(m.addChildren ?? {})) {
      for (const child of children) safely(nav.addChild, parentKey, child)
    }
    for (const key of m.remove ?? []) safely(nav.remove, key)
    for (const [key, patch] of Object.entries(m.update ?? {})) safely(nav.update, key, patch)
  }

  if (config.settingsNavGroups) {
    for (const group of config.settingsNavGroups) safely(settingsNav.addGroup, group)
  }

  if (config.settingsNav) {
    const m: SettingsNavMutations = Array.isArray(config.settingsNav)
      ? { add: config.settingsNav }
      : config.settingsNav
    for (const entry of m.add ?? []) safely(settingsNav.add, entry)
    for (const key of m.remove ?? []) safely(settingsNav.remove, key)
    for (const [key, patch] of Object.entries(m.update ?? {})) {
      safely(settingsNav.update, key, patch)
    }
  }

  if (config.slots) {
    for (const [name, list] of Object.entries(config.slots)) {
      for (const entry of list) safely(registerSlot, name, entry)
    }
  }

  if (config.tables) {
    for (const [tableKey, mutations] of Object.entries(config.tables)) {
      const mutator = tables[tableKey]
      for (const column of mutations.add ?? []) safely(mutator.addColumn, column)
      for (const key of mutations.remove ?? []) safely(mutator.removeColumn, key)
      for (const [key, patch] of Object.entries(mutations.update ?? {})) {
        safely(mutator.updateColumn, key, patch)
      }
    }
  }

  if (config.routes) {
    for (const entry of config.routes) safely(pluginRoutes.add, entry)
  }

  if (errors.length === 1) throw errors[0]
  if (errors.length > 1) {
    throw new AggregateError(errors, `${errors.length} registration(s) failed`)
  }
}
