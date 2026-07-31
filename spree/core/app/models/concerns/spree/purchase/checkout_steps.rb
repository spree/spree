module Spree
  module Purchase
    # Data-driven checkout-step introspection shared by Spree::Cart and
    # Spree::Order — computed from what the record actually requires
    # (Spree::Checkout::Requirements), never from a state column. The host
    # supplies delivery_required? (always true for orders, computed for
    # carts).
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

      def has_checkout_step?(step)
        step.present? && checkout_steps.include?(step.to_s)
      end

      def checkout_step_index(step)
        checkout_steps.index(step).to_i
      end

      # Customer-facing checkout step. Completed/canceled records are past
      # checkout; open ones report the first unmet requirement's step
      # ('cart' — missing line items — is not customer-facing and reports
      # as 'address').
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

      # Free checkouts skip the payment step.
      def payment_required?
        total.to_f > 0.0
      end

      # Whether the confirm/review step exists — computed from data only.
      def confirmation_required?
        Spree::Config[:always_include_confirm_step] ||
          payments.valid.map(&:payment_method).compact.any?(&:confirmation_required?)
      end
    end
  end
end
