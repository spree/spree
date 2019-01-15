import * as R from 'ramda'

import VARIANT from './variant'
import OPTION_TYPE from './option_type'
import PRODUCT_PROPERTY from './product_property'
import CLASSIFICATION from './classification'

export default {
  id: 1,
  name: 'Example product',
  description: 'Description',
  price: '15.99',
  display_price: '$15.99',
  available_on: '2012-10-17T03:43:57Z',
  slug: 'example-product',
  meta_description: null,
  meta_keywords: null,
  shipping_category_id: 1,
  taxon_ids: [1, 2, 3],
  total_on_hand: 10,
  master: R.merge(VARIANT, { is_master: true }),
  variants: [R.merge(VARIANT, { is_master: false })],
  option_types: [OPTION_TYPE],
  product_properties: [PRODUCT_PROPERTY],
  classifications: [CLASSIFICATION],
  has_variants: true
}
