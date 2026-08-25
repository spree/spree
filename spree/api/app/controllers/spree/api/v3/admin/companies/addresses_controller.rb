module Spree
  module Api
    module V3
      module Admin
        module Companies
          # A node's address book. Listing and creating live here; editing and
          # deleting an entry are addressed directly, since a caller holding
          # an entry id shouldn't have to know its company.
          class AddressesController < BaseController
            include Spree::Api::V3::Admin::Concerns::CompanyAddressParams

            before_action :authorize_parent_access!

            protected

            def model_class
              Spree::CompanyAddress
            end

            def serializer_class
              Spree.api.admin_company_address_serializer
            end

            def scope
              @parent.company_addresses
            end

            def parent_association
              :company_addresses
            end

            def collection_includes
              [:address]
            end
          end
        end
      end
    end
  end
end
