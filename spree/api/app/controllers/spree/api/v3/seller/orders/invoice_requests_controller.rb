module Spree
  module Api
    module V3
      module Seller
        module Orders
          # The buyer's requests for an invoice on this seller's order.
          class InvoiceRequestsController < BaseController
            protected

            def model_class
              Spree::InvoiceRequest
            end

            def serializer_class
              Spree.api.seller_invoice_request_serializer
            end

            def collection_includes
              [:billing_address, :invoice]
            end
          end
        end
      end
    end
  end
end
