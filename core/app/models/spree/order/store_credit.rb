module Spree
  class Order < Spree.base_class
    module StoreCredit
      def add_store_credit_payments(amount = nil)
        Spree::Dependencies.checkout_add_store_credit_service.constantize.call(order: self, amount: amount)
      end

      def remove_store_credit_payments
        Spree::Dependencies.checkout_remove_store_credit_service.constantize.call(order: self)
      end

      def covered_by_store_credit?
        user.present? && total_applied_store_credit.positive? && total_applied_store_credit >= total
      end
      alias covered_by_store_credit covered_by_store_credit?

      # Returns the total amount of store credits available to the user associated with the order.
      # Returns only store credit for this store and same currency as order
      #
      # @return [BigDecimal] The total amount of store credits available to the user associated with the order.
      def total_available_store_credit
        return 0.0 unless user

        user.total_available_store_credit(currency, store)
      end

      # Returns the available store credits for the user associated with the order.
      #
      # @return [Array<Spree::StoreCredit>] The available store credits for the user associated with the order.
      def available_store_credits
        return Spree::StoreCredit.none if user.nil?

        user.store_credits.for_store(store).where(currency: currency).available.sort_by(&:amount_remaining).reverse
      end

      def could_use_store_credit?
        return false if store.payment_methods.store_credit.available.empty?

        total_available_store_credit > 0
      end

      # Returns the total amount of the order minus the total amount of store credits applied to the order.
      #
      # @return [BigDecimal] The total amount of the order minus the total amount of store credits applied to the order.
      def order_total_after_store_credit
        total - total_applicable_store_credit
      end

      # Returns the total amount of the order minus the total amount of store credits applied to the order.
      #
      # @return [BigDecimal] The total amount of the order minus the total amount of store credits applied to the order.
      def total_minus_store_credits
        total - total_applied_store_credit
      end

      def total_applicable_store_credit
        if payment? || confirm? || complete?
          total_applied_store_credit
        else
          [total, user.try(:total_available_store_credit) || 0.0].min
        end
      end

      # Returns the total amount of store credits applied to the order.
      #
      # @return [BigDecimal] The total amount of store credits applied to the order.
      def total_applied_store_credit
        payments.store_credits.valid.sum(:amount)
      end

      # Returns true if the order is using store credit.
      #
      # @return [Boolean] True if the order is using store credit, false otherwise.
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

      def display_total_minus_store_credits
        Spree::Money.new(total_minus_store_credits, currency: currency)
      end
    end
  end
end
