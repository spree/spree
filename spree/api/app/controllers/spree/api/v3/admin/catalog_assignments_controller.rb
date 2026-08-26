module Spree
  module Api
    module V3
      module Admin
        # Withdrawing a catalog from an audience, addressed by assignment id.
        class CatalogAssignmentsController < ResourceController
          scoped_resource :products

          protected

          def model_class
            Spree::CatalogAssignment
          end

          def serializer_class
            Spree.api.admin_catalog_assignment_serializer
          end

          def scope
            Spree::CatalogAssignment.where(catalog_id: current_store.catalogs.select(:id)).
              accessible_by(current_ability, ability_action_for_request)
          end
        end
      end
    end
  end
end
