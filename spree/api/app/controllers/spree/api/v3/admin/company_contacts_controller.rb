module Spree
  module Api
    module V3
      module Admin
        # Removing a buyer's authority to purchase for a branch, addressed
        # directly by contact id.
        class CompanyContactsController < ResourceController
          scoped_resource :customers

          protected

          def model_class
            Spree::CompanyContact
          end

          def serializer_class
            Spree.api.admin_company_contact_serializer
          end

          def scope
            Spree::CompanyContact.where(
              company_location_id: Spree::CompanyLocation.where(company_id: current_store.companies.select(:id)).select(:id)
            ).accessible_by(current_ability, ability_action_for_request)
          end
        end
      end
    end
  end
end
