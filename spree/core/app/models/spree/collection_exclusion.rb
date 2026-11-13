module Spree
  # A product kept out of a collection whatever its rules match or a
  # merchant picked. Excluding removes the membership; lifting the exclusion
  # regenerates the collection, which brings the product back if the rules
  # still match.
  class CollectionExclusion < Spree.base_class
    has_prefix_id :cexcl

    belongs_to :collection, class_name: 'Spree::Collection', inverse_of: :exclusions, touch: true
    belongs_to :product, class_name: 'Spree::Product'

    validates :product_id, uniqueness: { scope: spree_base_uniqueness_scope + [:collection_id] }
    validate :product_belongs_to_collection_store, if: -> { collection && product }

    after_create :remove_membership
    after_destroy_commit -> { collection.enqueue_regenerate_products }

    self.whitelisted_ransackable_attributes = %w[collection_id product_id]

    private

    def product_belongs_to_collection_store
      errors.add(:product, :invalid) unless product.store_id == collection.store_id
    end

    def remove_membership
      Spree::Collections::RemoveProducts.call(collections: [collection], products: [product], regenerate: false)
    end
  end
end
