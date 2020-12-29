import SHIPPING_RATE from './shipping_rate'
import SHIPPING_METHOD from './shipping_method'
import MANIFEST from './manifest'

export default {
  id: 1,
  tracking: null,
  number: 'H71047039332',
  cost: '5.0',
  shipped_at: null,
  state: 'pending',
  shipping_rates: [SHIPPING_RATE],
  selected_shipping_rate: [SHIPPING_RATE],
  shipping_methods: [SHIPPING_METHOD],
  manifest: [MANIFEST],
  order_id: 1,
  stock_location_name: 'default'
}
