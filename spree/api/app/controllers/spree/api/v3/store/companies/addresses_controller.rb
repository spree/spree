module Spree
  module Api
    module V3
      module Store
        module Companies
          # The node's address book, managed by its members. Editing and
          # deleting an entry are addressed directly
          # (Store::CompanyAddressesController).
          class AddressesController < BaseController
            # Enumerated rather than borrowing a global list, which permits
            # :id, :user_id and :deleted_at.
            ADDRESS_KEYS = [
              :first_name, :last_name, :company, :address1, :address2, :city,
              :postal_code, :zipcode, :phone, :country_code, :state_code, :state_name, :label
            ].freeze

            # POST /api/v3/store/companies/:company_id/addresses
            def create
              entry = @parent.company_addresses.new(permitted_params)

              if entry.save
                render json: serialize_resource(entry), status: :created
              else
                render_validation_error(entry.errors)
              end
            end

            protected

            def model_class
              Spree::CompanyAddress
            end

            def serializer_class
              Spree.api.company_address_serializer
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

            def permitted_params
              params.permit(:label, :default_billing, :default_shipping, address: ADDRESS_KEYS)
            end
          end
        end
      end
    end
  end
end
