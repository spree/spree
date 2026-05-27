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
  // biome-ignore lint/suspicious/noExplicitAny: ColumnDef is generic per-row-type and the plugin layer can't know which.
  update?: Record<string, Partial<ColumnDef<any>>>
}

export interface DashboardPluginConfig {
  /** Sidebar entries. Each must have a unique `key`. */
  nav?: NavEntry[]
  /** Settings sub-shell groups (defined before any entry that uses the group key). */
  settingsNavGroups?: SettingsNavGroup[]
  /** Settings sub-shell entries. */
  settingsNav?: SettingsNavEntry[]
  /** Slot extensions keyed by slot name. Each entry must have a unique `id`. */
  slots?: Record<string, SlotEntry[]>
  /** Table mutations keyed by table key (see `defineTable`). */
  tables?: Record<string, TableMutations>
}

/**
 * Register all the extensions in `config` against the dashboard's registries.
 * Safe to call multiple times — each registry enforces uniqueness on its own
 * keys, so a duplicate `key`/`id` throws with a useful message.
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
    for (const entry of config.nav) safely(nav.add, entry)
  }

  if (config.settingsNavGroups) {
    for (const group of config.settingsNavGroups) safely(settingsNav.addGroup, group)
  }

  if (config.settingsNav) {
    for (const entry of config.settingsNav) safely(settingsNav.add, entry)
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

  if (errors.length === 1) throw errors[0]
  if (errors.length > 1) {
    throw new AggregateError(errors, `${errors.length} registration(s) failed`)
  }
}
