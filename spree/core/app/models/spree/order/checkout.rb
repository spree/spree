module Spree
  class Order < Spree.base_class
    # Data-driven checkout surface. The checkout state machine is gone
    # (docs/plans/6.0-cart-order-split.md): progression lives on the Cart via
    # Spree::Checkout::Requirements, and this module keeps only the
    # step-introspection API that serializers and completed orders still
    # need — computed from order data, never from a state column.
    module Checkout
      def self.included(klass)
        klass.class_eval do
          define_callbacks :updating_from_params

          # Steps derive from what the order actually requires.
          #
          # @return [Array<String>]
          def checkout_steps
            steps = ['address']
            steps << 'delivery' if delivery_required?
            steps << 'payment' if payment_required?
            steps << 'confirm' if respond_to?(:confirmation_required?) && confirmation_required?
            steps << 'complete'
            steps
          end

          def has_checkout_step?(step)
            step.present? && checkout_steps.include?(step.to_s)
          end

          def checkout_step_index(step)
            checkout_steps.index(step).to_i
          end

          # Customer-facing checkout step. Completed/canceled orders are past
          # checkout; open drafts report the first unmet requirement's step.
          #
          # @return [String]
          def current_checkout_step
            return 'complete' if completed? || canceled?

            first_unmet = Spree::Checkout::Requirements.new(self).call.first
            first_unmet ? first_unmet[:step].to_s : 'complete'
          end

          # Checkout steps that have already been completed, i.e. all steps
          # before {#current_checkout_step}. Does not include +'complete'+.
          #
          # @return [Array<String>]
          def completed_checkout_steps
            steps = checkout_steps.reject { |step| step == 'complete' }
            return steps if current_checkout_step == 'complete'

            index = steps.index(current_checkout_step) || 0
            steps.first(index)
          end

          def subscribe_to_newsletter
            return unless accept_marketing?

            Spree::NewsletterSubscriber.subscribe(email: email, user: user, store: store)
          end

          def assign_default_addresses!
            if user
              self.bill_address = user.bill_address if !bill_address_id && user.bill_address&.valid?
              # Skip the ship address for orders without a delivery step to
              # avoid triggering shipping-address validations
              self.ship_address = user.ship_address if !ship_address_id && user.ship_address&.valid? && checkout_steps.include?('delivery')
            end
          end

          def create_user_record
            return if user.present?
            return unless signup_for_an_account?

            Spree::Orders::CreateUserAccount.call(order: self, accepts_email_marketing: accept_marketing?)
          end
        end
      end
    end
  end
end
