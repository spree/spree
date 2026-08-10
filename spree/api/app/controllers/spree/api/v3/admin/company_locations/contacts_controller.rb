module Spree
  module Api
    module V3
      module Admin
        module CompanyLocations
          # The buyers who purchase for one branch.
          class ContactsController < ResourceController
            scoped_resource :customers

            # Overriding `scope` bypasses the base class's `accessible_by`, so
            # without this a role with no customer permission could still list
            # who buys for a branch — and contacts carry customer emails.
            before_action :authorize_parent_access!

            protected

            def model_class
              Spree::CompanyContact
            end

            def serializer_class
              Spree.api.admin_company_contact_serializer
            end

            # Filtered by ability as well as by store: a branch the caller may
            # not act on is not found rather than refused, so its existence
            # doesn't leak.
            def set_parent
              @parent = Spree::CompanyLocation.
                        where(company_id: current_store.companies.select(:id)).
                        accessible_by(current_ability, parent_ability_action).
                        find_by_prefix_id!(params[:company_location_id])
            end

            def authorize_parent_access!
              authorize_parent!(@parent)
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
