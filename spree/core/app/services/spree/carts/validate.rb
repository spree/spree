module Spree
  module Carts
    # The full completion battery, returning structured per-field errors with
    # stable codes: { step:, field:, code:, message: }. Also exposed read-only
    # so storefronts can render checkout readiness without attempting
    # completion.
    class Validate
      prepend Spree::ServiceModule::Base

      def call(cart:)
        errors = errors_for(cart)
        errors.empty? ? success(cart) : failure(cart, errors)
      end

      # @return [Array<Hash>] structured errors; empty when the cart can complete
      def errors_for(cart)
        errors = Spree::Checkout::Requirements.new(cart).call.map do |requirement|
          requirement.merge(code: code_for(requirement))
        end

        errors.concat(stock_errors(cart))
        errors << guest_policy_error(cart) if cart.guest_checkout_disallowed?
        errors.compact
      end

      private

      def code_for(requirement)
        "#{requirement[:field]}_required"
      end

      def stock_errors(cart)
        cart.line_items.includes(variant: :product).filter_map do |line_item|
          if line_item.variant.product.discontinued?
            error('cart', 'line_items', 'discontinued', Spree.t('cart_line_item.discontinued', li_name: line_item.name))
          elsif !line_item.sufficient_stock?
            error('cart', 'line_items', 'out_of_stock', Spree.t('cart_line_item.out_of_stock', li_name: line_item.name))
          end
        end
      end

      def guest_policy_error(cart)
        error('address', 'email', 'guest_checkout_not_allowed', Spree.t(:guest_checkout_not_allowed))
      end

      def error(step, field, code, message)
        { step: step, field: field, code: code, message: message }
      end
    end
  end
end
