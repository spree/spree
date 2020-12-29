import STOCK_ITEM from './stock_item'
import VARIANT from './variant'

export default {
  ...VARIANT,
  stock_items: [STOCK_ITEM]
}
