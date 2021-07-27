module Spree
  class StoreProduct < Spree::Base
    self.table_name = 'spree_products_stores'

    belongs_to :store, class_name: 'Spree::Store', touch: true
    belongs_to :product, class_name: 'Spree::Product', touch: true

    after_destroy :destroy_associated_product

    validates :store, :product, presence: true
    validates :store_id, uniqueness: { scope: :product_id }

    protected

    def destroy_associated_product
      return if Spree::StoreProduct.where.not(store_id: store.id).exists?(product_id: product.id)

      product.destroy!
    end
  end
end
