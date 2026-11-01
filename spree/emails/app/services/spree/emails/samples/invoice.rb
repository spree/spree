module Spree
  module Emails
    module Samples
      class Invoice < Base
        def self.record_type
          'invoice'
        end

        def variables
          {
            invoice: data(record, Spree::Emails::InvoiceSerializer),
            order: data(record.order, Spree::Emails::OrderSerializer),
            resend: false
          }
        end

        def currency
          record.currency
        end

        protected

        def records
          store.invoices.where.not(order_id: nil).order(created_at: :desc)
        end
      end
    end
  end
end
