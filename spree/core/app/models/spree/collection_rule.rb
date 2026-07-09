# frozen_string_literal: true

module Spree
  class CollectionRule < Spree.base_class
    has_prefix_id :crule

    MATCH_POLICIES = %w[is_equal_to is_not_equal_to contains does_not_contain].freeze

    belongs_to :collection, class_name: 'Spree::Collection', inverse_of: :collection_rules, touch: true

    validates :collection, :type, :value, presence: true
    validates :match_policy, inclusion: { in: MATCH_POLICIES }, presence: true

    after_commit :regenerate_collection_products,
                 if: -> { saved_change_to_value? || destroyed? || saved_change_to_match_policy? }

    delegate :store, to: :collection

    private

    def regenerate_collection_products
      collection.regenerate_products(only_once: true)
    end
  end
end
