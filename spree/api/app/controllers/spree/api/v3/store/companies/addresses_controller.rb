module Spree
  module Api
    module V3
      module Store
        module Companies
          # The node's address book, managed by its members. Editing and
          # deleting an entry are addressed directly
          # (Store::CompanyAddressesController).
          class AddressesController < BaseController
            include Spree::Api::V3::Store::Concerns::CompanyAddressDefaults
            # POST /api/v3/store/companies/:company_id/addresses
            def create
              address = @parent.addresses.new(permitted_params)

              if address.save
                apply_default_flags!(address)
                render json: serialize_resource(address), status: :created
              else
                render_validation_error(address.errors)
              end
            end

            protected

            def model_class
              Spree::Address
            end

            def serializer_class
              Spree.api.address_serializer
            end

            def scope
              @parent.addresses
            end

            def parent_association
              :addresses
            end

            def permitted_params
              params.permit(:label, *Spree::Api::V3::AddressParams::ADDRESS_KEYS)
            end
          end
        end
      end
    end
  end
end
