module Spree
  module Checkout
    # Built-in checkout requirements that map to the standard Spree checkout flow.
    #
    # Checks line items, email, shipping address, shipping method, and payment
    # against the cart — checkout is a cart-phase concern.
    #
    # @see Requirements
    class DefaultRequirements
      # @param cart [Spree::Cart]
      def initialize(cart)
        @cart = cart
      end

      # @return [Array<Hash{Symbol => String}>] unmet default requirements as
      #   +{ step:, field:, message: }+ hashes
      def call
        [].tap do |r|
          r << req('cart', 'line_items', Spree.t('checkout_requirements.line_items_required')) unless @cart.line_items.any?
          r << req('address', 'email', Spree.t('checkout_requirements.email_required')) unless @cart.email.present?
          r << req('address', 'ship_address', Spree.t('checkout_requirements.ship_address_required')) if @cart.requires_ship_address? && @cart.ship_address.blank?
          r << req('delivery', 'shipping_method', Spree.t('checkout_requirements.shipping_method_required')) if delivery_required? && !shipping_method_selected?
          r << req('payment', 'payment', Spree.t('checkout_requirements.payment_required')) if payment_required? && !payment_satisfied?
        end
      end

      private

      def delivery_required?
        @cart.delivery_required?
      end

      def shipping_method_selected?
        @cart.fulfillments.any? && @cart.fulfillments.all? { |fulfillment| fulfillment.delivery_method.present? }
      end

      def payment_required?
        @cart.payment_required?
      end

      def payment_satisfied?
        @cart.payments.valid.any?
      end

      def req(step, field, message)
        { step: step, field: field, message: message }
      end
    end
  end
end
