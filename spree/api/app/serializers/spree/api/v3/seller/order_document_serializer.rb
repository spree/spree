module Spree
  module Api
    module V3
      module Seller
        class OrderDocumentSerializer < Admin::OrderDocumentSerializer
          # The buyer's customer account and the operator's staff are not the
          # seller's to know; `uploaded_by_customer` says whose it is.
          _attributes.delete(:uploaded_by_id)
          _attributes.delete(:uploaded_by_type)

          attribute :download_url do |document|
            next nil unless document.file.attached?

            Spree::Core::Engine.routes.url_helpers.download_api_v3_seller_order_document_path(
              order_id: document.order.prefixed_id, id: document.prefixed_id
            )
          end
        end
      end
    end
  end
end
