module Spree
  module Api
    module V3
      module Admin
        module Companies
          # A node's address book — an entry is an ordinary address the node
          # owns, so the whole of it is reached through the node.
          class AddressesController < BaseController
            include Spree::Api::V3::CompanyAddressWrites

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

            def parent_association
              :addresses
            end
          end
        end
      end
    end
  end
end
