module Spree
  module OrderRouting
    # Shared validation for models carrying a +preferred_order_routing_strategy+
    # preference (Spree::Store, Spree::Channel). A blank value is allowed (it
    # falls back to the next level / the default Rules strategy); a present value
    # must name a registered Spree::OrderRouting::Strategy::Base subclass.
    module HasStrategyPreference
      extend ActiveSupport::Concern

      included do
        validate :order_routing_strategy_must_be_registered
      end

      private

      def order_routing_strategy_must_be_registered
        value = preferred_order_routing_strategy
        return if value.blank?
        return if Spree.order_routing.strategies.any? { |strategy| strategy.to_s == value.to_s }

        errors.add(
          :preferred_order_routing_strategy,
          Spree.t(:invalid_order_routing_strategy, scope: [:errors, :messages], default: 'is not a registered order routing strategy')
        )
      end
    end
  end
end
