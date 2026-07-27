import { registerSlot } from '@spree/dashboard-core'
import { ChannelRuleEditor } from './rule-channel'
import { CustomerRuleEditor } from './rule-customer'
import { CustomerGroupRuleEditor } from './rule-customer-group'
import { MarketRuleEditor } from './rule-market'
import { VolumeRuleEditor } from './rule-volume'
import { ruleFormSlot } from './types'

/**
 * Built-in editors for price rules whose configuration goes beyond a
 * simple integer / boolean / text preference. Imported once for its
 * side effects from the price-list detail route — extensions can
 * call `removeSlot(name, 'builtin')` to replace any of these with
 * their own.
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

registerSlot(ruleFormSlot('market_rule'), {
  id: 'builtin',
  component: MarketRuleEditor,
})

registerSlot(ruleFormSlot('channel_rule'), {
  id: 'builtin',
  component: ChannelRuleEditor,
})

// Custom editor solely to fix field order: the preference registry serializes
// max before min, and the generic form would render it that way.
registerSlot(ruleFormSlot('volume_rule'), {
  id: 'builtin',
  component: VolumeRuleEditor,
})
