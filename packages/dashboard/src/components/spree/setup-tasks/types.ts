import type { SetupTask, Store } from '@spree/admin-sdk'

/**
 * Slot name for a Getting Started task's card body. Register a component
 * here to replace the default copy + link CTA for a task — the way the
 * built-in storefront-connect flow is wired, and the extension point for
 * plugin-registered tasks (see `Spree.store_setup_tasks` on the backend).
 */
export const setupTaskSlot = (taskName: string) => `getting-started.task.${taskName}`

/** Context every setup-task slot component receives. */
export interface SetupTaskSlotContext {
  task: SetupTask
  store: Store
  storeId: string
}
