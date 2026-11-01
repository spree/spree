module Spree
  module Api
    module V3
      module Seller
        module Orders
          # Other paperwork on one of this seller's orders.
          class DocumentsController < BaseController
            include Spree::Api::V3::Orders::OrderDocumentActions

            protected

            def serializer_class
              Spree.api.seller_order_document_serializer
            end
          end
        end
      end
    end
  end
end
