module Spree
  module Api
    module V3
      module Admin
        module Customers
          class AddressesController < BaseController
            request_params 'CustomerAddressParams' do
              include_fields Spree::Api::V3::RequestShapes::ADDRESS_FIELDS
              string :firstname, :lastname, description: 'Older spellings of `first_name` and `last_name`.'
              string :alternative_phone
              boolean :quick_checkout
              boolean :is_default_billing, :is_default_shipping, permit: false,
                                                                 description: "Makes this the customer's default address of that kind."
            end

            # POST /api/v3/admin/customers/:customer_id/addresses
            def create
              authorize_resource!(Spree::Address.new(owner: @parent), :create)

              result = Spree.address_create_service.call(
                address_params: address_attrs,
                user: @parent,
                default_billing: default_billing_flag,
                default_shipping: default_shipping_flag
              )

              if result.success?
                render json: serialize_resource(result.value), status: :created
              else
                render_validation_error(result.value.errors)
              end
            end

            # PATCH /api/v3/admin/customers/:customer_id/addresses/:id
            def update
              authorize_resource!(@resource)

              result = Spree.address_update_service.call(
                address: @resource,
                address_params: address_attrs,
                default_billing: default_billing_flag,
                default_shipping: default_shipping_flag
              )

              if result.success?
                render json: serialize_resource(result.value)
              else
                render_validation_error(result.value.errors)
              end
            end

            # DELETE /api/v3/admin/customers/:customer_id/addresses/:id
            def destroy
              authorize_resource!(@resource)
              @resource.destroy
              head :no_content
            end

            protected

            def model_class
              Spree::Address
            end

            def serializer_class
              Spree.api.admin_address_serializer
            end

            private

            def address_attrs
              params.permit(*declared_permitted_attributes)
            end

            def default_billing_flag
              params[:is_default_billing].to_b
            end

            def default_shipping_flag
              params[:is_default_shipping].to_b
            end
          end
        end
      end
    end
  end
end
