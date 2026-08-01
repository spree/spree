module Spree
  module Checkout
    # Built-in checkout requirements that map to the standard Spree checkout flow.
    #
    # Checks line items, email, shipping address, shipping method, and payment
    # against the cart — checkout is a cart-phase concern. The heavier
    # completion-only checks (per-item stock, discontinued products, guest
    # policy) run only when +completion: true+ is passed, so the advisory
    # requirements feed on cart reads stays cheap.
    #
    # @see Requirements
    class DefaultRequirements
      # @param cart [Spree::Cart]
      def initialize(cart)
        @cart = cart
      end

      # @param completion [Boolean] include the completion-only checks
      # @return [Array<Hash{Symbol => String}>] unmet requirements as
      #   +{ step:, field:, code:, message: }+ hashes
      def call(completion: false)
        requirements = advisory_requirements
        return requirements unless completion

        requirements + completion_requirements
      end

      private

      def advisory_requirements
        [].tap do |r|
          r << req('cart', 'line_items', Spree.t('checkout_requirements.line_items_required')) unless @cart.line_items.any?
          r << req('address', 'email', Spree.t('checkout_requirements.email_required')) unless @cart.email.present?
          r << req('address', 'ship_address', Spree.t('checkout_requirements.ship_address_required')) if @cart.requires_ship_address? && @cart.ship_address.blank?
          r << req('delivery', 'shipping_method', Spree.t('checkout_requirements.shipping_method_required')) if delivery_required? && !shipping_method_selected?
          r << req('payment', 'payment', Spree.t('checkout_requirements.payment_required')) if payment_required? && !payment_satisfied?
        end
      end

      def completion_requirements
        errors = stock_errors
        errors << req('address', 'email', Spree.t(:guest_checkout_not_allowed), code: 'guest_checkout_not_allowed') if @cart.guest_checkout_disallowed?
        errors
      end

      def stock_errors
        @cart.line_items.includes(variant: :product).filter_map do |line_item|
          if line_item.variant.product.discontinued?
            req('cart', 'line_items', Spree.t('cart_line_item.discontinued', li_name: line_item.name), code: 'discontinued')
          elsif !line_item.sufficient_stock?
            req('cart', 'line_items', Spree.t('cart_line_item.out_of_stock', li_name: line_item.name), code: 'out_of_stock')
          end
        end
      end

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

      def req(step, field, message, code: nil)
        { step: step, field: field, code: code || "#{field}_required", message: message }
      end
    end
  end
end
