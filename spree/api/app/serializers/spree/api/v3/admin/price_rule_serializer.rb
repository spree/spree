module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::PriceRule (STI subclasses live under Spree::PriceRules).
        # Same shape as PromotionRuleSerializer so the SPA can drive both
        # editors from one generic preference-form component.
        class PriceRuleSerializer < V3::BaseSerializer
          typelize type: [:string, comment: 'Rule type. Built-in: channel_rule, customer_group_rule, market_rule, user_rule, volume_rule, zone_rule. Extensions may register more.'],
                   price_list_id: :string,
                   preferences: 'Record<string, unknown>'

          attributes created_at: :iso8601, updated_at: :iso8601

          attribute :type do |rule|
            rule.class.api_type
          end

          prefixed_id_attributes :price_list

          attribute :preferences, &:serialized_preferences

          # Embeds skip rules that don't carry the association (e.g.
          # VolumeRule has no markets/customers — the keys are omitted).
          many :markets,
               resource: proc { Spree.api.admin_market_serializer },
               if: proc { |rule| rule.respond_to?(:markets) }

          many :customer_groups,
               resource: proc { Spree.api.admin_customer_group_serializer },
               if: proc { |rule| rule.respond_to?(:customer_groups) }

          many :channels,
               resource: proc { Spree.api.admin_channel_serializer },
               if: proc { |rule| rule.respond_to?(:channels) }

          many :users,
               key: :customers,
               resource: proc { Spree.api.admin_customer_serializer },
               if: proc { |rule| rule.respond_to?(:users) }
        end
      end
    end
  end
end
