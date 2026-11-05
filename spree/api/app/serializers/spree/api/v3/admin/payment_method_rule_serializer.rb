module Spree
  module Api
    module V3
      module Admin
        class PaymentMethodRuleSerializer < BaseSerializer
          typelize type: [:string, comment: 'Rule type. Built-in: channel_rule, market_rule, order_total_rule, customer_group_rule, ' \
                                            'company_rule. Extensions may register more.'],
                   active: :boolean,
                   preferences: 'Record<string, unknown>'

          attributes :active, created_at: :iso8601, updated_at: :iso8601

          attribute :type do |rule|
            rule.class.api_type
          end

          attribute :preferences, &:serialized_preferences
        end
      end
    end
  end
end
