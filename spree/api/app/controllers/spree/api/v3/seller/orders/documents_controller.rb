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

            # A seller reads every document on their order but changes only
            # what their own team uploaded: the operator's and the buyer's
            # paperwork are not theirs to show, hide or delete.
            def scope
              return super if read_actions.include?(action_name) || action_name == 'create'

              super.where(uploaded_by_type: Spree.admin_user_class.to_s, uploaded_by_id: current_seller.users.select(:id))
            end
          end
        end
      end
    end
  end
end
