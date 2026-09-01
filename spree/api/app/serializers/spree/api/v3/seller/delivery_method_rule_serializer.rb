module Spree
  module Api
    module V3
      module Seller
        # One condition on a seller's delivery method — "orders over $50",
        # "under 20kg".
        #
        # Declared rather than subclassed from the admin serializer, like
        # every serializer on this branch. `product_ids` is absent: the rules
        # a seller may use are preference-only (see the seller delivery
        # methods controller), so no rule here carries an association.
        class DeliveryMethodRuleSerializer < BaseSerializer
          typelize type: :string, active: :boolean,
                   preferences: 'Record<string, unknown>',
                   preference_schema: "Array<{ key: string; type: string; default: unknown }>",
                   name: :string, description: :string

          attributes :active

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
        end
      end
    end
  end
end
