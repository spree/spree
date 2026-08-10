module Spree
  module Api
    module V3
      module Admin
        # A branch addressed directly. Reached through the store's companies so a
        # branch of another tenant's company is a 404.
        class CompanyLocationsController < ResourceController
          include Spree::Api::V3::Admin::Concerns::CompanyLocationParams

          scoped_resource :customers

          protected

          def model_class
            Spree::CompanyLocation
          end

          def serializer_class
            Spree.api.admin_company_location_serializer
          end

          def scope
            Spree::CompanyLocation.where(company_id: current_store.companies.select(:id))
          end

          def collection_includes
            [:billing_address, :shipping_address, :company_contacts]
          end
        end
      end
    end
  end
end
