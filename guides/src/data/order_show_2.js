import * as R from 'ramda'

import ORDER from './order'
import LINE_ITEM from './line_item'

export default R.merge(ORDER, {
  bill_address: null,
  ship_address: null,
  line_items: [R.merge(LINE_ITEM, { quantity: 5 })],
  payments: [],
  shipments: [],
  adjustments: [],
  credit_cards: [],
  permissions: { can_update: true }
})
