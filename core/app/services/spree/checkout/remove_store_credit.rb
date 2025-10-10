module Spree
  module Checkout
    class RemoveStoreCredit
      prepend Spree::ServiceModule::Base

      def call(order:)
        return failed unless order

        ApplicationRecord.transaction do
          order.payments.checkout.store_credits.map(&:invalidate!) unless order.completed?
        end

        order.reload.payments.store_credits.valid.any? ? failure(order) : success(order)
      end
    end
  end
end
