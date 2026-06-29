module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::PriceRule (STI subclasses live under Spree::PriceRules).
        # Same shape as PromotionRuleSerializer so the SPA can drive both
        # editors from one generic preference-form component.
        class PriceRuleSerializer < V3::BaseSerializer
          typelize type: :string,
                   price_list_id: :string,
                   preferences: 'Record<string, unknown>',
                   preference_schema: 'Array<{ key: string; type: string; default: unknown }>',
                   label: :string,
                   description: 'string | null'

          attributes created_at: :iso8601, updated_at: :iso8601

          attribute :type do |rule|
            rule.class.api_type
          end

          attribute :price_list_id do |rule|
            rule.price_list&.prefixed_id
          end

          attribute :preferences, &:serialized_preferences
          attribute :preference_schema, &:serialized_preference_schema

          attribute :label do |rule|
            rule.class.respond_to?(:human_name) ? rule.class.human_name : rule.class.to_s.demodulize
          end

          attribute :description do |rule|
            rule.class.respond_to?(:description) ? rule.class.description : nil
          end

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
