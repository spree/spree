# frozen_string_literal: true

module Spree
  class ProductCollection < Spree.base_class
    self.table_name = 'spree_product_collections'

    has_prefix_id :pcoll

    publishes_lifecycle_events only: %i[create delete]

    acts_as_list scope: :collection

    # products_count is a plain Rails counter_cache on the collection (collections are
    # flat, so — unlike Classification — there is no descendant-inclusive recompute).
    belongs_to :product, -> { with_deleted }, class_name: 'Spree::Product', counter_cache: :collections_count, touch: true,
                                              inverse_of: :product_collections
    belongs_to :collection, class_name: 'Spree::Collection', counter_cache: :products_count, touch: true,
                            inverse_of: :product_collections

    delegate :store, to: :product, allow_nil: true

    SOURCES = %w[manual rule].freeze

    # Nullable in the database until 6.2 (docs/plans/6.1-collections-merchandising.md):
    # every new row names it, and rows from before 6.1 still save until the
    # upgrade step fills theirs.
    validates :source, inclusion: { in: SOURCES }, on: :create
    validates :source, inclusion: { in: SOURCES }, allow_nil: true, on: :update

    validates :position, numericality: { only_integer: true, allow_blank: true, allow_nil: true }
    validates :collection_id, uniqueness: { scope: :product_id, message: :already_linked, allow_blank: true }

    # @return [Boolean] whether a merchant picked the product. A row from
    # before 6.1 has no source yet; on a manual collection it was picked.
    def hand_picked?
      source == 'manual' || (source.nil? && collection.manual?)
    end

    # Makes existing rule memberships hand-picked, keeping their positions.
    #
    # @param collection_ids [Array<Integer>, ActiveRecord::Relation]
    # @param product_ids [Array<Integer>, ActiveRecord::Relation]
    # @return [Integer] the rows changed
    def self.hand_pick(collection_ids:, product_ids:)
      where(collection_id: collection_ids, product_id: product_ids, source: [nil, 'rule']).
        update_all(source: 'manual', updated_at: Time.current)
    end

    self.whitelisted_ransackable_attributes = %w[collection_id product_id source]
  end
end
