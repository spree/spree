module Spree
  module Api
    module V3
      module Admin
        module Orders
          # The buyer's requests for an invoice on this order. Read-only: a
          # request is fulfilled by adding an invoice to the order.
          class InvoiceRequestsController < BaseController
            protected

            def model_class
              Spree::InvoiceRequest
            end

            def serializer_class
              Spree.api.admin_invoice_request_serializer
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
