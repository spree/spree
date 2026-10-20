module Spree
  module Api
    module V3
      module Store
        module Customer
          class AddressesController < ResourceController
            prepend_before_action :require_authentication!
            before_action :set_resource, only: [:show, :update, :destroy]

            request_params :address do |body|
              body.include_attributes Spree::Api::V3::Store::AddressRequestSchema
              body.require_attributes :first_name, :last_name, :address1, :city, :country_code, on: :create
              body.attribute :is_default_billing, :boolean, description: 'Makes this the default billing address.'
              body.attribute :is_default_shipping, :boolean, description: 'Makes this the default shipping address.'
            end

            # POST /api/v3/store/customers/me/addresses
            def create
              result = Spree.address_create_service.call(
                address_params: permitted_params,
                user: current_user
              )

              if result.success?
                render json: serialize_resource(result.value), status: :created
              else
                render_errors(result.value.errors)
              end
            end

            # PATCH /api/v3/store/customers/me/addresses/:id
            def update
              result = Spree.address_update_service.call(
                address: @resource,
                address_params: permitted_params
              )

              if result.success?
                render json: serialize_resource(result.value)
              else
                render_errors(result.value.errors)
              end
            end

            # DELETE /api/v3/store/customers/me/addresses/:id
            def destroy
              @resource.destroy!
              head :no_content
            rescue ActiveRecord::RecordNotDestroyed => e
              render_validation_error(e.record.errors.presence || e.message)
            end

            protected

            def set_parent
              @parent = current_user
            end

            def model_class
              Spree::Address
            end

            def serializer_class
              Spree.api.address_serializer
            end

            def permitted_params
              params.permit(*permitted_attributes)
            end
          end
        end
      end
    end
  end
end
