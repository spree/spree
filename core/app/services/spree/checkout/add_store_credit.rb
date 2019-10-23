module Spree
  module Checkout
    class AddStoreCredit
      prepend Spree::ServiceModule::Base

      def call(order:, amount: nil)
        @order = order
        return failed unless @order

        remaining_total = amount ? [amount, @order.outstanding_balance].min : @order.outstanding_balance

        ApplicationRecord.transaction do
          @order.payments.store_credits.where(state: :checkout).map(&:invalidate!)
          apply_store_credits(remaining_total) if @order.user&.store_credits&.any?
        end

        @order.reload.payments.store_credits.valid.any? ? success(@order) : failure(@order)
      end

      private

      def apply_store_credits(remaining_total)
        payment_method = Spree::PaymentMethod::StoreCredit.available.first
        raise 'Store credit payment method could not be found' unless payment_method

        @order.user.store_credits.order_by_priority.each do |credit|
          break if remaining_total.zero?
          next if credit.amount_remaining.zero?

          amount_to_take = store_credit_amount(credit, remaining_total)
          create_store_credit_payment(payment_method, credit, amount_to_take)
          remaining_total -= amount_to_take
        end
      end

      def create_store_credit_payment(payment_method, credit, amount)
        @order.payments.create!(
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
