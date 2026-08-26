module Spree
  module Api
    module V3
      module Admin
        # An address-book entry addressed directly. Reached through the
        # store's companies so an entry of another tenant's company is a 404.
        class CompanyAddressesController < ResourceController
          include Spree::Api::V3::Admin::Concerns::CompanyAddressParams

          scoped_resource :customers

          protected


          def model_class
            Spree::Address
          end

          def serializer_class
            Spree.api.admin_company_address_serializer
          end

          def scope
            Spree::Address.where(owner_type: 'Spree::Company',
                                 owner_id: current_store.companies.select(:id)).
              accessible_by(current_ability, ability_action_for_request)
          end
        end
      end
    end
  end
end
