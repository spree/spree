import { registerSlot } from '@/lib/slot-registry'
import { CustomerRuleEditor } from './rule-customer'
import { CustomerGroupRuleEditor } from './rule-customer-group'
import { ruleFormSlot } from './types'

/**
 * Built-in editors for price rules whose configuration goes beyond a
 * simple integer / boolean / text preference. Imported once for its
 * side effects from the price-list detail route — extensions can
 * call `removeSlot(name, 'builtin')` to replace any of these with
 * their own.
 *
 * VolumeRule's two integer preferences (`min_quantity`, `max_quantity`)
 * render fine via the generic `<PreferencesForm>` fallback, so it
 * doesn't need a custom editor here.
 */

// `user_rule` is the legacy wire shorthand for Spree::PriceRules::UserRule —
// the SPA calls it "Customer rule" but the wire name and `user_ids`
// preference are unchanged for backwards compatibility.
registerSlot(ruleFormSlot('user_rule'), {
  id: 'builtin',
  component: CustomerRuleEditor,
})

registerSlot(ruleFormSlot('customer_group_rule'), {
  id: 'builtin',
  component: CustomerGroupRuleEditor,
})
