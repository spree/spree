module Spree
  module Checkout
    # Built-in checkout requirements that map to the standard Spree checkout flow.
    #
    # Checks line items, email, shipping address, shipping method, and payment.
    # In Spree 6 these same checks will read from the +Cart+ model instead of
    # the state machine — the API contract stays identical.
    #
    # @see Requirements
    class DefaultRequirements
      # @param order [Spree::Order]
      def initialize(order)
        @order = order
      end

      # @return [Array<Hash{Symbol => String}>] unmet default requirements as
      #   +{ step:, field:, message: }+ hashes
      def call
        [].tap do |r|
          r << req('cart', 'line_items', Spree.t('checkout_requirements.line_items_required')) unless @order.line_items.any?
          r << req('address', 'email', Spree.t('checkout_requirements.email_required')) unless @order.email.present?
          r << req('address', 'ship_address', Spree.t('checkout_requirements.ship_address_required')) if @order.requires_ship_address? && @order.ship_address.blank?
          r << req('delivery', 'shipping_method', Spree.t('checkout_requirements.shipping_method_required')) if delivery_required? && !shipping_method_selected?
          r << req('payment', 'payment', Spree.t('checkout_requirements.payment_required')) if payment_required? && !payment_satisfied?
        end
      end

      private

      def delivery_required?
        @order.has_checkout_step?('delivery') && @order.delivery_required?
      end

      def shipping_method_selected?
        @order.shipments.any? && @order.shipments.all? { |s| s.shipping_method.present? }
      end

      def payment_required?
        @order.has_checkout_step?('payment') && @order.payment_required?
      end

      def payment_satisfied?
        @order.payments.valid.any?
      end

      def req(step, field, message)
        { step: step, field: field, message: message }
      end
    end
  end
end
