module Spree
  class Promotion
    module Rules
      # Promotion rule matching an order against a set of collections, the
      # same shape as the Category rule. Reads the collections' materialized
      # membership, so nothing is evaluated at checkout; item-level actions
      # discount only the members.
      class Collection < Spree::PromotionRule
        MATCH_POLICIES = %w[any all].freeze

        has_many :promotion_rule_collections, class_name: 'Spree::PromotionRuleCollection',
                                              foreign_key: 'promotion_rule_id',
                                              inverse_of: :promotion_rule,
                                              dependent: :delete_all
        has_many :collections, through: :promotion_rule_collections, class_name: 'Spree::Collection'

        self.additional_permitted_attributes = [collection_ids: []]

        preference :match_policy, :string, default: MATCH_POLICIES.first, choices: MATCH_POLICIES

        validate :collections_belong_to_store

        def self.api_type
          'collection'
        end

        # Resolved through the promotion's own store, prefixed and raw ids
        # alike, so another store's collection raises instead of linking.
        def collection_ids=(ids)
          super(ids_within_store(ids, promotion&.store&.collections))
        end

        def eligible_collection_ids
          @eligible_collection_ids ||= promotion_rule_collections.pluck(:collection_id)
        end

        def eligible?(order, _options = {})
          return true if eligible_collection_ids.empty?

          order_collection_ids = Spree::ProductCollection.where(product_id: order.product_ids, collection_id: eligible_collection_ids).
                                 distinct.pluck(:collection_id)

          if preferred_match_policy == 'all'
            unless (eligible_collection_ids - order_collection_ids).empty?
              eligibility_errors.add(:base, eligibility_error_message(:missing_collection))
            end
          elsif order_collection_ids.empty?
            eligibility_errors.add(:base, eligibility_error_message(:no_matching_collections))
          end

          eligibility_errors.empty?
        end

        def actionable?(line_item)
          Spree::ProductCollection.exists?(collection_id: eligible_collection_ids, product_id: line_item.product_id)
        end

        private

        def collections_belong_to_store
          return if promotion.nil? || collection_ids.empty?
          return if (collection_ids - promotion.store.collections.where(id: collection_ids).ids).empty?

          errors.add(:collections, :invalid)
        end
      end
    end
  end
end
