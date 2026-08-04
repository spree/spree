module Spree
  module Api
    module V3
      module Admin
        # Cross-order listing of returns — "what is awaiting receipt across
        # the whole store". Read-only by route: opening a return needs an
        # order, so creation and the status transitions stay on the nested
        # Orders::ReturnsController.
        class ReturnsController < ResourceController
          # Post-sale records are order data: a key that may read orders may
          # read these, and nothing here writes.
          scoped_resource :orders

          protected

          def model_class
            Spree::Return
          end

          def serializer_class
            Spree.api.admin_return_serializer
          end

          def collection_includes
            [:order, :reason, :stock_location, { return_line_items: :variant }]
          end
        end
      end
    end
  end
end
