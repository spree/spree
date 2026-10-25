module Spree
  module Emails
    module Samples
      class Return < Base
        def self.record_type
          'return'
        end

        def variables
          {
            return: data(record, Spree::Emails::ReturnSerializer),
            order: data(record.order, Spree::Emails::OrderSerializer),
            resend: false
          }
        end

        def currency
          record.order.currency
        end

        protected

        def records
          store.returns.order(created_at: :desc)
        end
      end
    end
  end
end
