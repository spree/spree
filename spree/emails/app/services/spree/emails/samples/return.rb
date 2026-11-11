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
            order_url: placeholder_url('account/orders/order'),
            policy_url: placeholder_url('policies/return-policy'),
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
