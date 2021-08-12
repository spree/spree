module Spree
  module CreditCards
    class Destroy
      prepend Spree::ServiceModule::Base

      def call(card:)
        ApplicationRecord.transaction do
          run :invalidate_payments
          run :void_payments
          run :destroy
        end
      end

      protected

      def invalidate_payments(card:)
        payment_scope(card).checkout.each(&:invalidate!)

        success(card: card)
      end

      def void_payments(card:)
        payment_scope(card).where.not(state: :checkout).each(&:void!)

        success(card: card)
      end

      def destroy(card:)
        if card.destroy
          success(card: card)
        else
          failure(card.errors.full_messages.to_sentance)
        end
      end

      def payment_scope(card)
        card.payments.valid.joins(:order).merge(Spree::Order.incomplete)
      end
    end
  end
end
