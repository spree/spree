module Spree
  module Api
    module V3
      module Admin
        module Companies
          # A node's address book — an entry is an ordinary address the node
          # owns, so the whole of it is reached through the node.
          class AddressesController < BaseController
            include Spree::Api::V3::CompanyAddressWrites

            request_params 'CompanyAddressParams' do
              include_fields Spree::Api::V3::RequestShapes::ADDRESS_FIELDS
              boolean :default_billing, :default_shipping, permit: false,
                                                           description: 'True makes this the default address of that kind, false gives the slot up, and leaving it out keeps the current default.'
            end

            before_action :authorize_parent_access!

            # POST /api/v3/admin/companies/:company_id/addresses
            def create
              result = Spree.address_create_service.call(
                address_params: permitted_params,
                owner: @parent,
                **default_flags
              )

              if result.success?
                render json: serialize_resource(result.value), status: :created
              else
                render_errors(result.value.errors)
              end
            end

            # PATCH /api/v3/admin/companies/:company_id/addresses/:id
            def update
              result = Spree.address_update_service.call(
                address: @resource,
                address_params: permitted_params,
                **default_flags
              )

              if result.success?
                render json: serialize_resource(result.value)
              else
                render_errors(result.value.errors)
              end
            end

            protected

            def model_class
              Spree::Address
            end

            def serializer_class
              Spree.api.admin_address_serializer
            end

            def scope
              @parent.addresses
            end

            def permitted_params
              params.permit(*declared_permitted_attributes)
            end
          end
        end
      end
    end
  end
end
