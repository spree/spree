module Spree
  module StoreCredits
    class Apply
      prepend Spree::ServiceModule::Base

      def call(order:, amount: nil)
        @order = order
        return failed unless @order

        # Never negative: a paid or overpaid order has a zero-or-negative
        # outstanding balance, and this service runs on every recalculation.
        # Without the clamp the loop below would keep going and write a store
        # credit payment for a negative amount.
        remaining_total = [amount ? [amount, @order.outstanding_balance].min : @order.outstanding_balance, 0].max

        return failure(nil, Spree.t(:error_user_does_not_have_any_store_credits)) unless @order.customer&.store_credits&.any?

        ApplicationRecord.transaction do
          existing = @order.payments.store_credits.where(status: :checkout)

          if existing.any?
            update_existing_payments(existing, remaining_total)
          else
            apply_store_credits(remaining_total)
          end
        end

        if @order.reload.payments.store_credits.valid.any?
          # Legacy update hooks are an order-side extension seam; carts have none.
          @order.update_hooks.each { |hook| @order.send(hook) } if @order.respond_to?(:update_hooks)
          success(@order)
        else
          failure(@order)
        end
      end

      private

      # Update existing checkout store credit payments in place to avoid
      # creating unnecessary invalid payment records on every recalculation.
      def update_existing_payments(payments, remaining_total)
        payments.each do |payment|
          credit = payment.source
          available = credit.amount_remaining + payment.amount
          new_amount = [available, remaining_total].min

          if new_amount.positive?
            payment.update_column(:amount, new_amount)
            remaining_total -= new_amount
          else
            payment.invalidate!
          end
        end

        # If there's still remaining total, apply from additional store credits
        apply_store_credits(remaining_total) if remaining_total.positive?
      end

      def apply_store_credits(remaining_total)
        payment_method = Spree::PaymentMethod::StoreCredit.available.first
        raise 'Store credit payment method could not be found' unless payment_method

        @order.customer.store_credits.for_store(@order.store).oldest_first.each do |credit|
          break unless remaining_total.positive?
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
          status: 'checkout',
          response_code: credit.generate_authorization_code
        )
      end

      def store_credit_amount(credit, total)
        [credit.amount_remaining, total].min
      end
    end
  end
end
