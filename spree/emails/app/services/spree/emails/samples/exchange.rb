module Spree
  module Emails
    module Samples
      class Exchange < Base
        def self.record_type
          'exchange'
        end

        def variables
          {
            exchange: data(record, Spree::Emails::ExchangeSerializer),
            order: data(record.order, Spree::Emails::OrderSerializer),
            order_url: placeholder_url('account/orders/order'),
            policy_url: placeholder_url('policies/return-policy')
          }
        end

        def currency
          record.order.currency
        end

        protected

        def records
          store.exchanges.order(created_at: :desc)
        end
      end
    end
  end
end
