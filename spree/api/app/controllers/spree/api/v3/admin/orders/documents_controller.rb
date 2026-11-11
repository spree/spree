module Spree
  module Api
    module V3
      module Admin
        module Orders
          # Other paperwork on the order, with per-document buyer visibility.
          class DocumentsController < BaseController
            include Spree::Api::V3::Orders::OrderDocumentActions

            protected

            def serializer_class
              Spree.api.admin_order_document_serializer
            end
          end
        end
      end
    end
  end
end
