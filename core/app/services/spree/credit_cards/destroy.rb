module Spree
  module CreditCards
    class Destroy
      prepend Spree::ServiceModule::Base

      def call(card:)
        ActiveRecord::Base.transaction do
          card.payments.
            valid.
            joins(:order).
            merge(Spree::Order.incomplete).
            each(&:void!)
          card.destroy
        end
      end
    end
  end
end
