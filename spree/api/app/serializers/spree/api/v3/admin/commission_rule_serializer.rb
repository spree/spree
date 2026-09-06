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
          typelize type: :string,
                   commission_rate_id: :string,
                   preferences: 'Record<string, unknown>',
                   preference_schema: 'Array<{ key: string; type: string; default: unknown }>',
                   product_ids: [:string, multi: true]

          attributes created_at: :iso8601, updated_at: :iso8601

          attribute :type do |rule|
            rule.class.api_type
          end

          attribute :commission_rate_id do |rule|
            rule.commission_rate&.prefixed_id
          end

          attribute :preferences, &:serialized_preferences
          attribute :preference_schema, &:serialized_preference_schema

          # Catalog-scale references live in their own table rather than the
          # preferences blob, so they are read back separately — omitted
          # entirely for rule kinds that carry none.
          attribute :product_ids, if: proc { |rule| rule.respond_to?(:product_prefixed_ids) } do |rule|
            rule.product_prefixed_ids
          end
        end
      end
    end
  end
end
