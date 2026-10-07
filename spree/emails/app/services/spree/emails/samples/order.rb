module Spree
  module Emails
    module Samples
      # Order confirmation and cancellation.
      class Order < Base
        def self.record_type
          'order'
        end

        def variables
          { order: data(record, Spree::Emails::OrderSerializer), resend: false }
        end

        protected

        def records
          store.orders.complete.order(completed_at: :desc)
        end
      end
    end
  end
end
