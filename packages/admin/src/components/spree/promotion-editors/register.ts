import { registerSlot } from '@/lib/slot-registry'
import { AdjustmentActionEditor } from './action-adjustment'
import { CategoryRuleEditor } from './rule-category'
import { CountryRuleEditor } from './rule-country'
import { CustomerGroupRuleEditor } from './rule-customer-group'
import { ProductRuleEditor } from './rule-product'
import { UserRuleEditor } from './rule-user'
import { actionFormSlot, ruleFormSlot } from './types'

/**
 * Built-in editors for promotion rules and actions whose configuration
 * goes beyond a simple `preferences` hash. Imported once for its
 * side effects from the promotion detail route — extensions can call
 * `removeSlot(name, 'builtin')` to replace any of these with their own.
 *
 * Slot keys follow `promotion.rule_form.<rule.type>` and
 * `promotion.action_form.<action.type>`. Rules/actions whose type isn't
 * registered fall through to the generic `<DefaultRuleEditor>` /
 * `<DefaultActionEditor>` (preferences-only) in the parent route.
 */

// Rules with associations (products, taxons → categories, users) or
// preference arrays of prefixed IDs (customer groups, countries).
registerSlot(ruleFormSlot('product'), {
  id: 'builtin',
  component: ProductRuleEditor,
})

registerSlot(ruleFormSlot('category'), {
  id: 'builtin',
  component: CategoryRuleEditor,
})

registerSlot(ruleFormSlot('customer'), {
  id: 'builtin',
  component: UserRuleEditor,
})

registerSlot(ruleFormSlot('customer_group'), {
  id: 'builtin',
  component: CustomerGroupRuleEditor,
})

registerSlot(ruleFormSlot('country'), {
  id: 'builtin',
  component: CountryRuleEditor,
})

// Both adjustment actions wrap a calculator and share the same editor.
registerSlot(actionFormSlot('create_adjustment'), {
  id: 'builtin',
  component: AdjustmentActionEditor,
})

registerSlot(actionFormSlot('create_item_adjustments'), {
  id: 'builtin',
  component: AdjustmentActionEditor,
})
