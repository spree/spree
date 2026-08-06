module Spree
  module Api
    module V3
      module Admin
        class DeliveryMethodRuleSerializer < BaseSerializer
          typelize type: :string, active: :boolean,
                   preferences: 'Record<string, unknown>',
                   preference_schema: "Array<{ key: string; type: string; default: unknown }>",
                   name: :string, description: :string,
                   product_ids: [:string, multi: true]

          attributes :active, created_at: :iso8601, updated_at: :iso8601

          # Wire shorthand (e.g. `item_total_rule`), matching the types
          # discovery endpoint.
          attribute :type do |rule|
            rule.class.api_type
          end

          attribute :name do |rule|
            rule.class.human_name
          end

          attribute :description do |rule|
            rule.class.human_description
          end

          attribute :preferences, &:serialized_preferences
          attribute :preference_schema, &:serialized_preference_schema

          # Association-backed config (ExcludedProductsRule); empty for
          # preference-only rules. Same name read and written.
          attribute :product_ids do |rule|
            rule.respond_to?(:product_prefixed_ids) ? rule.product_prefixed_ids : []
          end
        end
      end
    end
  end
end
