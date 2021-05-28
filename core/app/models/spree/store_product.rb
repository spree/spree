module Spree
  class StoreProduct < Spree::Base
    self.table_name = 'spree_products_stores'

    belongs_to :store, class_name: 'Spree::Store', touch: true
    belongs_to :product, class_name: 'Spree::Product', touch: true

    validates :store, :product, presence: true
    validates :store_id, uniqueness: { scope: :product_id }
  end
end
