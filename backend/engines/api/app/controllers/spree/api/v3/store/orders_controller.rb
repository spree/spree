module Spree
  module Api
    module V3
      module Store
        class OrdersController < ResourceController
          include Spree::Api::V3::OrderConcern

          # Skip base controller's set_resource and define our own complete list
          skip_before_action :set_resource
          before_action :set_resource, only: [:show, :update, :destroy, :next, :advance, :complete]
          prepend_before_action :require_authentication!, only: [:index]

          # POST  /api/v3/store/orders (public - guest checkout)
          def create
            @resource = Spree::Order.create!(
              store: current_store,
              currency: current_currency,
              user: current_user # nil for guests
            )

            render json: serialize_resource(@resource).merge(
              order_token: @resource.token # Return token for guest access
            ), status: :created
          end

          # PATCH  /api/v3/store/orders/:id
          #
          # Accepts flat parameters:
          #   {
          #     "email": "customer@example.com",
          #     "currency": "EUR",
          #     "ship_address": { "firstname": "John", "country_iso": "US", ... },
          #     "bill_address": { "firstname": "John", "country_iso": "US", ... }
          #   }
          #
          def update
            result = Spree::Api::V3::Orders::Update.call(
              order: @order,
              params: order_params
            )

            if result.success?
              render json: serialize_resource(@order.reload)
            else
              render_service_error(result.error, code: ERROR_CODES[:validation_error])
            end
          end

          # PATCH  /api/v3/store/orders/:id/next
          def next
            result = Spree.checkout_next_service.call(order: @order)

            if result.success?
              render json: serialize_resource(@order)
            else
              render_service_error(result.error, code: ERROR_CODES[:order_cannot_transition])
            end
          end

          # PATCH  /api/v3/store/orders/:id/advance
          def advance
            result = Spree.checkout_advance_service.call(order: @order)

            if result.success?
              render json: serialize_resource(@order)
            else
              render_service_error(result.error, code: ERROR_CODES[:order_cannot_transition])
            end
          end

          # PATCH  /api/v3/store/orders/:id/complete
          def complete
            result = Spree.checkout_complete_service.call(order: @order)

            if result.success?
              render json: serialize_resource(@order)
            else
              render_service_error(result.error, code: ERROR_CODES[:order_already_completed])
            end
          end

          protected

          # Override scope to avoid accessible_by (Order permissions use blocks)
          def scope
            order_scope
          end

          # Override set_resource to scope lookup by user or order token (IDOR prevention)
          def set_resource
            @order = order_scope.find_by_prefix_id!(params[:id])
            @resource = @order
            authorize_resource!(@order)
          end

          # override authorize_resource! to pass the order token
          # Maps custom checkout actions to appropriate permissions
          def authorize_resource!(resource = @resource, action = action_name.to_sym)
            mapped_action = case action
                            when :next, :advance, :complete
                              :update # Checkout actions require update (non-completed order)
                            else
                              action
                            end
            authorize!(mapped_action, resource, order_token)
          end

          def model_class
            Spree::Order
          end

          def serializer_class
            Spree.api.order_serializer
          end

          def order_params
            params.permit(
              :email,
              :currency,
              :special_instructions,
              :ship_address_id,
              :bill_address_id,
              ship_address: address_params,
              bill_address: address_params
            )
          end

          def address_params
            [
              :id, :firstname, :lastname, :address1, :address2,
              :city, :zipcode, :phone, :company,
              :country_iso, :state_abbr, :state_name
            ]
          end
        end
      end
    end
  end
end
