import * as R from 'ramda'

import VARIANT from './variant'
import LINE_ITEM from './line_item'

const rejectList = ['variant', 'adjustments']
const hasRejectedKey = list => R.includes(rejectList, R.keys(list))
const filteredLineItem = R.reject(hasRejectedKey, LINE_ITEM)

export default {
  id: 1,
  state: 'on_hand',
  variant_id: 1,
  shipment_id: 1,
  variant: VARIANT,
  line_item: filteredLineItem
}
