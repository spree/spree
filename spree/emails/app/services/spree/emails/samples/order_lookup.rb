module Spree
  module Emails
    module Samples
      # The "find my order" link.
      class OrderLookup < Order
        def variables
          { order: data(record, Spree::Emails::OrderSerializer), order_url: placeholder_url('orders/order') }
        end
      end
    end
  end
end
