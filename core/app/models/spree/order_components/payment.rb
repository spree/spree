require 'active_support/concern'

module Spree
  module OrderComponents
    module Payment
      extend ActiveSupport::Concern

      included do
        attr_accessible :payments_attributes
        has_many :payments, :dependent => :destroy

        accepts_nested_attributes_for :payments

        validate :has_available_payment

        def outstanding_balance
          total - payment_total
        end

        def outstanding_balance?
          self.outstanding_balance != 0
        end

        def payment
          payments.first
        end

        def available_payment_methods
          @available_payment_methods ||= PaymentMethod.available(:front_end)
        end

        def payment_method
          if payment and payment.payment_method
            payment.payment_method
          else
            available_payment_methods.first
          end
        end

        private

        def has_available_payment
          return unless :delivery == state_name.to_sym
          errors.add(:base, :no_payment_methods_available) if available_payment_methods.empty?
        end
      end
    end
  end
end
