import OPTION_VALUE from './option_value'
import IMAGE from './image'

export default {
  id: 1,
  name: 'Ruby on Rails Tote',
  sku: 'ROR-00011',
  price: '15.99',
  weight: null,
  height: null,
  width: null,
  depth: null,
  is_master: true,
  slug: 'ruby-on-rails-tote',
  description: 'A text description of the product.',
  track_inventory: true,
  cost_price: null,
  option_values: [OPTION_VALUE],
  images: [IMAGE],
  display_price: '$15.99',
  options_text: '(Size: small, Colour: red)',
  in_stock: true,
  is_backorderable: true,
  is_orderable: true,
  total_on_hand: 10,
  is_destroyed: false
}
