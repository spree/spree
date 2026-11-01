module Spree
  module Api
    module V3
      module Store
        module Orders
          # The buyer's invoices, receipts and credit notes on their order.
          class InvoicesController < Store::ResourceController
            include Spree::Api::V3::Store::CustomerOrderParent
            include ActiveStorage::SetCurrent

            before_action :set_resource, only: [:download]

            # GET /api/v3/store/orders/:order_id/invoices/:id/download
            def download
              send_data(
                @resource.file.download,
                filename: @resource.file.filename.to_s,
                type: @resource.file.content_type || 'application/pdf',
                disposition: 'attachment'
              )
            end

            protected

            def model_class
              Spree::Invoice
            end

            def serializer_class
              Spree.api.invoice_serializer
            end

            def scope
              @parent.invoices
            end

            def collection_includes
              [:issuer, { file_attachment: :blob }]
            end

            def read_actions
              %w[index download]
            end
          end
        end
      end
    end
  end
end
