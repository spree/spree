module Spree
  module Api
    module V3
      module Seller
        # The rows of one of this seller's imports — the failure report
        # (`GET /seller/imports/:import_id/rows?q[status_eq]=failed`).
        #
        # Read-only, and gated by the write key like its parent: the rows carry
        # the uploaded data back, so seeing them is seeing the upload.
        class ImportRowsController < Seller::ResourceController
          scoped_resource :products

          protected

          def model_class
            Spree::ImportRow
          end

          def serializer_class
            Spree.api.seller_import_row_serializer
          end

          def parent_association
            :rows
          end

          def set_parent
            @parent = parent_import
            authorize_parent!(@parent)
          end

          # Resolved through this seller's own imports, so an import id
          # belonging to the operator or to another seller is a 404 rather than
          # a readable row list.
          def parent_import
            @parent_import ||= Spree::Import.for_store(current_store).
                               for_seller(current_seller).
                               where(type: Seller::ImportsController::PERMITTED_TYPES).
                               find_by_prefix_id!(params[:import_id])
          end

          def action_kind
            'write'
          end
        end
      end
    end
  end
end
