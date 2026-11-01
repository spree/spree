module Spree
  module Api
    module V3
      module Seller
        module Orders
          # Invoices on one of this seller's orders, and uploading one from
          # the seller's own invoicing software.
          class InvoicesController < BaseController
            include Spree::Api::V3::Orders::InvoiceUpload

            protected

            def serializer_class
              Spree.api.seller_invoice_serializer
            end
          end
        end
      end
    end
  end
end
