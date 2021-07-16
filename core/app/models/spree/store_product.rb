module Spree
  class StoreProduct < Spree::Base
    self.table_name = 'spree_products_stores'

    belongs_to :store, class_name: 'Spree::Store', touch: true
    belongs_to :product, class_name: 'Spree::Product', touch: true

    # before_destroy -> { p 'debtu p', product.id, Spree::StoreProduct.pluck(:product_id, :store_id), Spree::StoreProduct.where.not(store_id: store.id).find_by(product_id: product.id).nil?;
    # p 'destroyed' if Spree::StoreProduct.where.not(store_id: store.id).find_by(product_id: product.id).nil? }

    validates :store, :product, presence: true
    # validates :store_id, uniqueness: { scope: :product_id }
  end
end
