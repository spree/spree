module Spree
  module Purchase
    # Data-driven checkout-step introspection for Spree::Cart — computed
    # from what the cart actually requires (Spree::Checkout::Requirements),
    # never from a state column. Cart-only: an order is past checkout by
    # definition. The payment predicates the step list reads
    # (payment_required?/confirmation_required?) live in
    # {Spree::Purchase::PaymentProcessing}.
    module CheckoutSteps
      # The Registry owns the step vocabulary and applicability — built-in
      # and registered custom steps alike (see
      # Spree::Checkout::Registry.base_steps / .register_step).
      #
      # @return [Array<String>]
      def checkout_steps
        Spree::Checkout::Registry.step_names_for(self)
      end

      # @param step [String, Symbol]
      # @return [Boolean]
      def has_checkout_step?(step)
        step.present? && checkout_steps.include?(step.to_s)
      end

      # @param step [String]
      # @return [Integer] position of the step, 0 when unknown
      def checkout_step_index(step)
        checkout_steps.index(step).to_i
      end

      # Customer-facing checkout step. Completed carts are past checkout;
      # open ones report the first unmet requirement's step ('cart' —
      # missing line items — is not customer-facing and reports as
      # 'address').
      #
      # Only a completed cart reports 'complete'. An open cart with nothing
      # outstanding is not finished, it is ready to be placed, so it waits
      # on {#final_checkout_step}
      # @return [String]
      def current_checkout_step
        return 'complete' if completed?

        first_unmet = Spree::Checkout::Requirements.new(self).call.first
        return final_checkout_step if first_unmet.nil?

        step = first_unmet[:step].to_s
        step == 'cart' ? 'address' : step
      end

      # @return [String]
      def final_checkout_step
        checkout_steps.reject { |step| step == 'complete' }.last || 'address'
      end

      # Checkout steps before {#current_checkout_step}; never includes
      # 'complete'.
      #
      # @return [Array<String>]
      def completed_checkout_steps
        steps = checkout_steps.reject { |step| step == 'complete' }
        return steps if current_checkout_step == 'complete'

        index = steps.index(current_checkout_step) || 0
        steps.first(index)
      end
    end
  end
end
