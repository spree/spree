module Spree
  module Api
    module V3
      module Admin
        module Customers
          class AddressesController < BaseController

            # POST /api/v3/admin/customers/:customer_id/addresses
            def create
              authorize_resource!(Spree::Address.new(user_id: @parent.id), :create)

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

            def parent_association
              :addresses
            end

            def model_class
              Spree::Address
            end

            def serializer_class
              Spree.api.admin_address_serializer
            end

            private

            def address_attrs
              params.permit(
                :firstname, :lastname, :first_name, :last_name,
                :address1, :address2, :city,
                :country_iso, :state_abbr, :country_id, :state_id,
                :zipcode, :postal_code, :phone, :alternative_phone,
                :state_name, :company, :label, :quick_checkout
              )
            end

            def default_billing_flag
              ActiveModel::Type::Boolean.new.cast(params[:is_default_billing])
            end

            def default_shipping_flag
              ActiveModel::Type::Boolean.new.cast(params[:is_default_shipping])
            end
          end
        end
      end
    end
  end
end
