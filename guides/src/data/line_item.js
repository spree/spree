import * as R from 'ramda'
import VARIANT from './variant'

export default {
  id: 1,
  quantity: 2,
  price: '19.99',
  variant_id: 1,
  variant: R.merge(VARIANT, { product_id: 1 }),
  adjustments: [],
  single_display_amount: '$19.99',
  display_total: '$39.99',
  total: '39.99'
}
