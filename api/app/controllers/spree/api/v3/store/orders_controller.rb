module Spree
  module Api
    module V3
      module Store
        class OrdersController < Store::ResourceController
          include Spree::Api::V3::OrderConcern

          # Override authorization for orders
          skip_before_action :set_resource, only: [:index, :create]
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
          def update
            if @order.update(permitted_params)
              render json: serialize_resource(@order.reload)
            else
              render_errors(@order.errors)
            end
          end

          # PATCH  /api/v3/store/orders/:id/next
          def next
            result = next_service.call(order: @order)

            if result.success?
              render json: serialize_resource(@order)
            else
              render_service_error(result.error, code: ERROR_CODES[:order_cannot_transition])
            end
          end

          # PATCH  /api/v3/store/orders/:id/advance
          def advance
            result = advance_service.call(order: @order)

            if result.success?
              render json: serialize_resource(@order)
            else
              render_service_error(result.error, code: ERROR_CODES[:order_cannot_transition])
            end
          end

          # PATCH  /api/v3/store/orders/:id/complete
          def complete
            result = complete_service.call(order: @order)

            if result.success?
              render json: serialize_resource(@order)
            else
              render_service_error(result.error, code: ERROR_CODES[:order_already_completed])
            end
          end

          # PATCH  /api/v3/store/orders/:id/cancel
          def cancel
            @order.cancel!
            render json: serialize_resource(@order)
          end

          protected

          # Override scope to avoid accessible_by (Order permissions use blocks)
          def scope
            current_store.orders.where(user: current_user)
          end

          # Override set_resource to use friendly finder and order_token authorization
          def set_resource
            @order = current_store.orders.friendly.find(params[:id])
            @resource = @order
            authorize_resource!(@order)
          end

          # override authorize_resource! to pass the order token
          def authorize_resource!(resource = @resource, action = action_name.to_sym)
            authorize!(action, resource, order_token)
          end

          def model_class
            Spree::Order
          end

          def serializer_class
            Spree.api.order_serializer
          end

          def permitted_params
            params.require(:order).permit(Spree::PermittedAttributes.checkout_attributes)
          end

          def update_service
            Spree::Api::Dependencies.storefront_checkout_update_service.constantize
          end

          def next_service
            Spree::Api::Dependencies.storefront_checkout_next_service.constantize
          end

          def advance_service
            Spree::Api::Dependencies.storefront_checkout_advance_service.constantize
          end

          def complete_service
            Spree::Api::Dependencies.storefront_checkout_complete_service.constantize
          end
        end
      end
    end
  end
end
