import * as R from 'ramda'

import SHIPPING_RATE from './shipping_rate'
import INVENTORY_UNIT from './inventory_unit'
import ORDER from './order'
import ADDRESS from './address'
import PAYMENT from './payment'

export default {
  id: 1,
  tracking: null,
  number: 'H123456789',
  cost: '5.0',
  shipped_at: null,
  state: 'pending',
  selected_shipping_rate: SHIPPING_RATE,
  inventory_units: [INVENTORY_UNIT],
  order: R.merge(ORDER, {
    state: 'payment',
    bill_address: ADDRESS,
    ship_address: ADDRESS,
    adjustments: [],
    payments: [PAYMENT]
  })
}
