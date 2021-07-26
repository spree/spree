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
      return unless Spree::StoreProduct.where(product_id: product.id).not(store_id: store.id).any?

      product.destroy!
    end
  end
end
