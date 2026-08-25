module Spree
  module Api
    module V3
      module Admin
        # Removing a buyer's standing over a node, addressed directly by
        # membership id.
        class CompanyMembershipsController < ResourceController
          scoped_resource :customers

          protected

          def model_class
            Spree::CompanyMembership
          end

          def serializer_class
            Spree.api.admin_company_membership_serializer
          end

          def scope
            Spree::CompanyMembership.where(company_id: current_store.companies.select(:id)).
              accessible_by(current_ability, ability_action_for_request)
          end
        end
      end
    end
  end
end
