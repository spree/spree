module Spree
  class Order < Spree::Base
    module StoreCredit
      def add_store_credit_payments(amount = nil)
        ActiveSupport::Deprecation.warn(<<-EOS, caller)
          Spree::Order#add_store_credit_payments method is deprecated and will be removed in Spree 4.0.
          Please use Spree::Checkout::AddStoreCredit service to remove item from cart.
        EOS

        Spree::Checkout::AddStoreCredit.call(order: self, amount: amount)
      end

      def remove_store_credit_payments
        payments.checkout.store_credits.map(&:invalidate!) unless completed?
      end

      def covered_by_store_credit?
        return false unless user

        user.total_available_store_credit >= total
      end
      alias covered_by_store_credit covered_by_store_credit?

      def total_available_store_credit
        return 0.0 unless user

        user.total_available_store_credit
      end

      def could_use_store_credit?
        total_available_store_credit > 0
      end

      def order_total_after_store_credit
        total - total_applicable_store_credit
      end

      def total_applicable_store_credit
        if payment? || confirm? || complete?
          total_applied_store_credit
        else
          [total, (user.try(:total_available_store_credit) || 0.0)].min
        end
      end

      def total_applied_store_credit
        payments.store_credits.valid.sum(:amount)
      end

      def using_store_credit?
        total_applied_store_credit > 0
      end

      def display_total_applicable_store_credit
        Spree::Money.new(-total_applicable_store_credit, currency: currency)
      end

      def display_total_applied_store_credit
        Spree::Money.new(-total_applied_store_credit, currency: currency)
      end

      def display_order_total_after_store_credit
        Spree::Money.new(order_total_after_store_credit, currency: currency)
      end

      def display_total_available_store_credit
        Spree::Money.new(total_available_store_credit, currency: currency)
      end

      def display_store_credit_remaining_after_capture
        Spree::Money.new(total_available_store_credit - total_applicable_store_credit, currency: currency)
      end
    end
  end
end
