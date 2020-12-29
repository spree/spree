import * as R from 'ramda'
import NEW_ORDER from './new_order'

export default R.merge(NEW_ORDER, {
  bill_address: null,
  ship_address: null,
  line_items: [],
  payments: [],
  shipments: [],
  adjustments: [],
  credit_cards: [],
  permissions: { can_update: true }
})
