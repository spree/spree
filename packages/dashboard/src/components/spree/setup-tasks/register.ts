import { registerSlot } from '@spree/dashboard-core'
import { AddProductsTask } from './add-products-task'
import { StorefrontConnectTask } from './storefront-connect-task'
import { type SetupTaskSlotContext, setupTaskSlot } from './types'

/**
 * Built-in task card bodies that go beyond the default copy + link CTA.
 * Imported once for its side effects from the Getting Started route.
 *
 * Extensions register their own bodies under `getting-started.task.<name>`
 * (matching the task key they added to `Spree.store_setup_tasks`), and can
 * call `removeSlot(name, 'builtin')` to replace a built-in one.
 */
registerSlot<SetupTaskSlotContext>(setupTaskSlot('setup_storefront'), {
  id: 'builtin',
  component: StorefrontConnectTask,
})

registerSlot<SetupTaskSlotContext>(setupTaskSlot('add_products'), {
  id: 'builtin',
  component: AddProductsTask,
})
