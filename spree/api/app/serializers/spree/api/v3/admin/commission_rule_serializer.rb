module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::CommissionRule — one condition on a rate.
        #
        # Admin-only, like everything commission: what a marketplace charges is
        # between it and its sellers, so there is no Store API counterpart.
        #
        # Shaped like the price-rule serializer so one generic editor can drive
        # both: the wire `type`, the values, and the schema describing them.
        class CommissionRuleSerializer < V3::BaseSerializer
          typelize type: [:string, comment: 'Rule type. Built-in: seller_rule, category_rule, product_rule, item_total_rule. Extensions may register more.'],
                   commission_rate_id: :string,
                   preferences: 'Record<string, unknown>',
                   preference_schema: 'Array<{ key: string; type: string; default: unknown }>',
                   product_ids: 'Array<string> | null',
                   seller_ids: 'Array<string> | null',
                   category_ids: 'Array<string> | null'

          attributes created_at: :iso8601, updated_at: :iso8601

          attribute :type do |rule|
            rule.class.api_type
          end

          attribute :commission_rate_id do |rule|
            rule.commission_rate&.prefixed_id
          end

          attribute :preferences, &:serialized_preferences
          attribute :preference_schema, &:serialized_preference_schema

          # Reference lists are returned as prefixed IDs to match the rest of
          # the API. Product ids are read through a join table; seller and
          # category ids live in preferences server-side but are not exposed
          # that way on the wire — the picker round-trips prefixed ids.
          attribute :product_ids do |rule|
            rule.product_prefixed_ids if rule.respond_to?(:product_prefixed_ids)
          end

          attribute :seller_ids do |rule|
            rule.sellers.map(&:prefixed_id) if rule.respond_to?(:sellers)
          end

          attribute :category_ids do |rule|
            rule.categories.map(&:prefixed_id) if rule.respond_to?(:categories)
          end

          many :sellers,
               resource: proc { Spree.api.admin_seller_serializer },
               if: proc { |rule| rule.respond_to?(:sellers) }

          many :categories,
               resource: proc { Spree.api.admin_category_serializer },
               if: proc { |rule| rule.respond_to?(:categories) }
        end
      end
    end
  end
end
