module Spree
  module Api
    module V3
      module Seller
        class OrderDocumentSerializer < Admin::OrderDocumentSerializer
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
