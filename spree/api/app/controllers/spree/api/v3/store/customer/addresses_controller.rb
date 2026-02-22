module Spree
  module Api
    module V3
      module Store
        module Customer
          class AddressesController < ResourceController
            prepend_before_action :require_authentication!
            before_action :set_resource, only: [:show, :update, :destroy, :mark_as_default]

            # POST /api/v3/store/customer/addresses
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

            # PATCH /api/v3/store/customer/addresses/:id/mark_as_default
            def mark_as_default
              kind = params[:kind].to_s

              unless %w[billing shipping].include?(kind)
                return render_error(
                  code: ERROR_CODES[:invalid_request],
                  message: 'kind must be billing or shipping',
                  status: :unprocessable_content
                )
              end

              attribute = kind == 'billing' ? :bill_address_id : :ship_address_id
              current_user.update!(attribute => @resource.id)

              render json: serialize_resource(@resource.reload)
            end

            # PATCH /api/v3/store/customer/addresses/:id
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

            protected

            def set_parent
              @parent = current_user
            end

            def parent_association
              :addresses
            end

            def model_class
              Spree::Address
            end

            def serializer_class
              Spree.api.address_serializer
            end

            def permitted_params
              params.permit(
                :firstname, :lastname, :address1, :address2, :city,
                :zipcode, :phone, :company, :country_iso, :state_abbr, :state_name
              )
            end
          end
        end
      end
    end
  end
end
