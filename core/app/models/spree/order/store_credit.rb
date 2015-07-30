module Spree
  class Order < Spree::Base
    module StoreCredit
      def add_store_credit_payments
        payments.store_credits.where(state: 'checkout').map(&:invalidate!)

        remaining_total = outstanding_balance

        if user && user.store_credits.any?
          payment_method = Spree::PaymentMethod.find_by_type('Spree::PaymentMethod::StoreCredit')
          raise "Store credit payment method could not be found" unless payment_method

          user.store_credits.order_by_priority.each do |credit|
            break if remaining_total.zero?
            next if credit.amount_remaining.zero?

            amount_to_take = store_credit_amount(credit, remaining_total)
            create_store_credit_payment(payment_method, credit, amount_to_take)
            remaining_total -= amount_to_take
          end
        end

        # we add this on before payment, so this should be removed or moved to another place.
        #
        # if payments.valid.sum(:amount) != total
        #   errors.add(:base, Spree.t("store_credit.errors.unable_to_fund")) and return false
        # end
        #
      end

      def covered_by_store_credit?
        return false unless user
        user.total_available_store_credit >= total
      end
      alias_method :covered_by_store_credit, :covered_by_store_credit?

      def total_available_store_credit
        return 0.0 unless user
        user.total_available_store_credit
      end

      def order_total_after_store_credit
        total - total_applicable_store_credit
      end

      def total_applicable_store_credit
        if payment? || confirm? || complete?
          payments.store_credits.valid.sum(:amount)
        else
          [total, (user.try(:total_available_store_credit) || 0.0)].min
        end
      end

      def display_total_applicable_store_credit
        Spree::Money.new(-total_applicable_store_credit, currency: currency)
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

      private

      def create_store_credit_payment(payment_method, credit, amount)
        payments.create!(
          source: credit,
          payment_method: payment_method,
          amount: amount,
          state: 'checkout',
          response_code: credit.generate_authorization_code
        )
      end

      def store_credit_amount(credit, total)
        [credit.amount_remaining, total].min
      end
    end
  end
end
