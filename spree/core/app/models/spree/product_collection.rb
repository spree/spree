# frozen_string_literal: true

module Spree
  class ProductCollection < Spree.base_class
    self.table_name = 'spree_product_collections'

    acts_as_list scope: :collection

    # products_count is a plain Rails counter_cache on the collection (collections are
    # flat, so — unlike Classification — there is no descendant-inclusive recompute).
    belongs_to :product, class_name: 'Spree::Product', counter_cache: :collections_count, touch: true
    belongs_to :collection, class_name: 'Spree::Collection', counter_cache: :products_count, touch: true,
                            inverse_of: :product_collections

    validates :product, :collection, presence: true
    validates :position, numericality: { only_integer: true, allow_blank: true, allow_nil: true }
    validates :collection_id, uniqueness: { scope: :product_id, message: :already_linked, allow_blank: true }

    self.whitelisted_ransackable_attributes = %w[collection_id product_id]
  end
end
