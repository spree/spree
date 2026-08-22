module Spree
  module Api
    module V3
      module Admin
        module Companies
          # Branches of one company. Listing and creating live here; editing and
          # deleting a branch are addressed directly, since a caller holding a
          # branch id shouldn't have to know its company.
          class LocationsController < BaseController
            include Spree::Api::V3::Admin::Concerns::ExternalReferences
            include Spree::Api::V3::Admin::Concerns::CompanyLocationParams

            before_action :authorize_parent_access!

            protected

            def model_class
              Spree::CompanyLocation
            end

            def serializer_class
              Spree.api.admin_company_location_serializer
            end

            def scope
              @parent.company_locations
            end

            def parent_association
              :company_locations
            end

            def collection_includes
              [:billing_address, :shipping_address, :company_contacts]
            end
          end
        end
      end
    end
  end
end
