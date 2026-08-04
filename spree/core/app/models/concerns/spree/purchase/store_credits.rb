module Spree
  module Purchase
    # Store-credit application surface shared by Spree::Cart and
    # Spree::Order (carts reach user through the customer alias).
    module StoreCredits
      def add_store_credit_payments(amount = nil)
        Spree.checkout_add_store_credit_service.call(order: self, amount: amount)
      end

      def remove_store_credit_payments
        Spree.checkout_remove_store_credit_service.call(order: self)
      end

      def covered_by_store_credit?
        customer.present? && total_applied_store_credit.positive? && total_applied_store_credit >= total
      end
      alias covered_by_store_credit covered_by_store_credit?

      # Only store credit for this store and the record's currency.
      #
      # @return [BigDecimal]
      def total_available_store_credit
        return 0.0 unless customer

        customer.total_available_store_credit(currency, store)
      end

      # @return [Array<Spree::StoreCredit>]
      def available_store_credits
        return Spree::StoreCredit.none if customer.nil?

        customer.store_credits.for_store(store).where(currency: currency).available.sort_by(&:amount_remaining).reverse
      end

      def could_use_store_credit?
        return false if store.payment_methods.store_credit.available.empty?

        total_available_store_credit > 0
      end

      def order_total_after_store_credit
        total - total_applicable_store_credit
      end

      def total_minus_store_credits
        total - total_applied_store_credit
      end

      def total_applicable_store_credit
        # Once payments exist (or the record completed), report what was
        # actually applied; before that, what could be applied.
        if completed? || payments.valid.any?
          total_applied_store_credit
        else
          [total, customer.try(:total_available_store_credit) || 0.0].min
        end
      end

      # @return [BigDecimal]
      def total_applied_store_credit
        if payments.loaded?
          payments.
            find_all(&:store_credit?).
            reject(&:has_invalid_state?).
            sum(&:amount) || BigDecimal::ZERO
        else
          payments.store_credits.valid.sum(:amount)
        end
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

      def display_total_minus_store_credits
        Spree::Money.new(total_minus_store_credits, currency: currency)
      end
    end
  end
end
