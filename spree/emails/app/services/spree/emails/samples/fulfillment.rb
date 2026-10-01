module Spree
  module Emails
    module Samples
      class Fulfillment < Base
        def self.record_type
          'fulfillment'
        end

        def variables
          {
            fulfillment: data(record, Spree::Emails::FulfillmentSerializer),
            order: data(record.order, Spree::Emails::OrderSerializer),
            resend: false
          }
        end

        def currency
          record.order.currency
        end

        protected

        def records
          store.fulfillments.order(created_at: :desc)
        end
      end
    end
  end
end
