module Spree
  module Api
    module V3
      module Seller
        module Orders
          # Invoices on one of this seller's orders, and uploading one from
          # the seller's own invoicing software.
          class InvoicesController < BaseController
            include Spree::Api::V3::Orders::InvoiceUpload

            # Only an order the seller invoices: a platform-remitted seller's
            # sales are invoiced by the store, in the store's numbering.
            def create
              return super if Spree::Invoice.issuer_for(@parent) == current_seller

              render_error(
                code: ERROR_CODES[:validation_error],
                message: I18n.t('spree.invoices.errors.store_invoices_order'),
                status: :unprocessable_content
              )
            end

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
