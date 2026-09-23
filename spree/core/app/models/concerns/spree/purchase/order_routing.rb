module Spree
  module Purchase
    # Resolves the order routing strategy for a cart or an order, so storefront
    # checkout and staff-built orders pick fulfillment locations the same way
    # (docs/plans/6.0-order-routing.md).
    module OrderRouting
      extend ActiveSupport::Concern

      # Resolves the routing strategy from the channel override first, then the
      # store default. Only a registered Spree::OrderRouting::Strategy::Base
      # subclass is used; any other value (an unregistered/typo'd class, or a
      # strategy that was unregistered after being persisted) is logged and
      # skipped rather than raised, falling back to the default Rules strategy
      # so a misconfiguration can't take down cart display or checkout.
      #
      # @return [Spree::OrderRouting::Strategy::Base]
      def order_routing_strategy
        klass = valid_order_routing_strategy_class(channel&.preferred_order_routing_strategy) ||
                valid_order_routing_strategy_class(store&.preferred_order_routing_strategy) ||
                Spree::OrderRouting::Strategy::Rules

        klass.new(order: self)
      end

      # Cascade for the `preferred_location` rule kind: the location chosen on
      # this purchase (a customer's pickup counter, or staff's "fulfill from
      # here"), then the staff member who created it. Channel and B2B sources
      # are layered in by their respective plans.
      #
      # @return [Integer, nil]
      def inferred_preferred_stock_location_id
        preferred_stock_location_id.presence ||
          try(:created_by)&.try(:preferred_stock_location_id)
      end

      private

      def valid_order_routing_strategy_class(klass_name)
        return if klass_name.blank?

        klass = Spree.order_routing.strategies.find { |strategy| strategy.to_s == klass_name.to_s }
        return klass if klass

        Rails.logger.warn(
          "[Spree] Ignoring unregistered order routing strategy #{klass_name.inspect} " \
          "for #{self.class.name} #{prefixed_id.inspect}; falling back to the default strategy."
        )
        nil
      end
    end
  end
end
