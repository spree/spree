module Spree
  # Membership of one product in a catalog's assortment, manually ordered.
  class CatalogProduct < Spree.base_class
    has_prefix_id :catp

    acts_as_list scope: :catalog_id

    belongs_to :catalog, class_name: 'Spree::Catalog', touch: true, inverse_of: :catalog_products
    belongs_to :product, class_name: 'Spree::Product'

    validates :product_id, uniqueness: { scope: [:catalog_id, *spree_base_uniqueness_scope] }
    validate :product_in_same_store

    delegate :store, :store_id, to: :catalog

    private

    def product_in_same_store
      return if product.nil? || catalog.nil?
      return if product.store_id == catalog.store_id

      errors.add(:product, :invalid)
    end
  end
end
