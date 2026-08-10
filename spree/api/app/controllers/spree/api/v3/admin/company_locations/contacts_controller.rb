module Spree
  module Api
    module V3
      module Admin
        module CompanyLocations
          # The buyers who purchase for one branch.
          class ContactsController < ResourceController
            scoped_resource :customers

            protected

            def model_class
              Spree::CompanyContact
            end

            def serializer_class
              Spree.api.admin_company_contact_serializer
            end

            def set_parent
              @parent = Spree::CompanyLocation.
                        where(company_id: current_store.companies.select(:id)).
                        find_by_prefix_id!(params[:company_location_id])
            end

            def scope
              @parent.company_contacts
            end

            def parent_association
              :company_contacts
            end

            def collection_includes
              [:customer]
            end

            def permitted_params
              params.permit(:customer_id, :role)
            end
          end
        end
      end
    end
  end
end
