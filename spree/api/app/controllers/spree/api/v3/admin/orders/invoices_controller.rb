module Spree
  module Api
    module V3
      module Admin
        module Orders
          # An order's invoices, receipts and credit notes, and uploading one
          # issued in another system.
          class InvoicesController < BaseController
            include Spree::Api::V3::Orders::InvoiceUpload

            protected

            def serializer_class
              Spree.api.admin_invoice_serializer
            end
          end
        end
      end
    end
  end
end
