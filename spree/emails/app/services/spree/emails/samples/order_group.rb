module Spree
  module Emails
    module Samples
      # The confirmation of a purchase that divided into several orders.
      class OrderGroup < Base
        def self.record_type
          'order_group'
        end

        def variables
          { order_group: data(record, Spree::Emails::OrderGroupSerializer), resend: false }
        end

        protected

        def records
          store.order_groups.order(created_at: :desc)
        end
      end
    end
  end
end
