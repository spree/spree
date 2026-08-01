module Spree
  module Purchase
    # Data-driven checkout-step introspection for Spree::Cart — computed
    # from what the cart actually requires (Spree::Checkout::Requirements),
    # never from a state column. Cart-only: an order is past checkout by
    # definition. The payment predicates the step list reads
    # (payment_required?/confirmation_required?) live in
    # {Spree::Purchase::PaymentProcessing}.
    module CheckoutSteps
      # @return [Array<String>]
      def checkout_steps
        steps = ['address']
        steps << 'delivery' if delivery_required?
        steps << 'payment' if payment_required?
        steps << 'confirm' if confirmation_required?
        steps << 'complete'
        steps
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
      # @return [String]
      def current_checkout_step
        return 'complete' if completed?

        first_unmet = Spree::Checkout::Requirements.new(self).call.first
        step = first_unmet ? first_unmet[:step].to_s : 'complete'
        step == 'cart' ? 'address' : step
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
