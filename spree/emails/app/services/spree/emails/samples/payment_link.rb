module Spree
  module Emails
    module Samples
      class PaymentLink < Order
        def variables
          { order: data(record, Spree::Emails::OrderSerializer), payment_url: placeholder_url('checkout/payment') }
        end

        protected

        def records
          store.orders.order(created_at: :desc)
        end
      end
    end
  end
end
