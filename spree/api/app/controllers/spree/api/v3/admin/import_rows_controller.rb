module Spree
  module Api
    module V3
      module Admin
        # Row listing for one import — the failure report
        # (`GET /admin/imports/:import_id/rows?q[status_eq]=failed`).
        # Read-only; gated like its parent surface by the write scope of the
        # imported resource, since rows expose the uploaded data.
        class ImportRowsController < ResourceController
          protected

          def model_class
            Spree::ImportRow
          end

          def serializer_class
            Spree.api.admin_import_row_serializer
          end

          def parent_association
            :rows
          end

          def set_parent
            @parent = parent_import
            authorize_parent!(@parent)
          end

          # Resolved through the imports scope so store isolation matches the
          # parent surface; memoized because the API-key scope gate also needs
          # it (it runs before set_parent).
          def parent_import
            @parent_import ||= Spree::Import.for_store(current_store).
                               accessible_by(current_ability, :show).
                               find_by_prefix_id!(params[:import_id])
          end

          def action_kind
            'write'
          end

          def scoped_resource_name
            parent_import.class.required_scope || :all
          end
        end
      end
    end
  end
end
