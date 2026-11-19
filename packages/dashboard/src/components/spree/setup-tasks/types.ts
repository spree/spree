import type { SetupTask, Store } from '@spree/admin-sdk'
import type { TFunction } from 'i18next'

/**
 * Slot name for a Getting Started task's card body. Register a component
 * here to replace the default copy + link CTA for a task — the way the
 * built-in storefront-connect flow is wired, and the extension point for
 * plugin-registered tasks (see `Spree.store_setup_tasks` on the backend).
 */
export const setupTaskSlot = (taskName: string) => `getting-started.task.${taskName}`

/**
 * Where each built-in task whose default card body (copy + CTA button)
 * suffices is done. Tasks needing real UI register a slot component under
 * `getting-started.task.<name>` instead — see setup-tasks/register.ts.
 */
export const SETUP_TASK_LINKS: Record<string, string> = {
  setup_payment_method: '/$storeId/settings/payment-methods',
  add_products: '/$storeId/products',
  set_customer_support_email: '/$storeId/settings/emails',
  setup_taxes_collection: '/$storeId/settings/taxes/rates',
}

/** Context every setup-task slot component receives. */
export interface SetupTaskSlotContext {
  task: SetupTask
  store: Store
  storeId: string
}

/**
 * A task's title, description or CTA. Extension tasks without registered copy
 * fall back to a humanized name for the title and render no description/CTA.
 * Going through defaultValue keeps the lookup inside i18next, so copy
 * registered later (e.g. by a plugin locale bundle) wins without a code change.
 */
export function setupTaskCopy(
  t: TFunction,
  taskName: string,
  facet: 'title' | 'description' | 'cta',
): string | null {
  const humanized = taskName.replace(/_/g, ' ').replace(/^./, (c) => c.toUpperCase())
  const fallback = facet === 'title' ? humanized : ''
  return (
    t(`admin.pages.getting_started.tasks.${taskName}.${facet}`, { defaultValue: fallback }) || null
  )
}
