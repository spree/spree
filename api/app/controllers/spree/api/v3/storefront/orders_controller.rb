module Spree
  module Api
    module V3
      module Storefront
        class OrdersController < ResourceController
          include Spree::Api::V3::GuestOrderAccess

          # Override authorization for orders
          skip_before_action :set_resource, only: [:index, :create]
          before_action :require_authentication!, only: [:index]
          before_action :set_order, only: [:show, :update, :destroy, :next, :advance, :complete, :cancel]
          before_action :authorize_order_access!, only: [:show, :update, :destroy, :next, :advance, :complete, :cancel]

          # GET /api/v3/storefront/orders (requires auth)
          def index
            @collection = ransack_collection

            render json: {
              data: serialize_collection(@collection),
              meta: collection_meta(@collection)
            }
          end

          # POST /api/v3/storefront/orders (public - guest checkout)
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

          # GET /api/v3/storefront/orders/:id
          def show
            render json: serialize_resource(@order)
          end

          # PATCH /api/v3/storefront/orders/:id
          def update
            result = update_service.call(
              order: @order,
              params: params,
              permitted_attributes: permitted_params,
              request_env: request.headers.env
            )

            if result.success?
              render json: serialize_resource(@order)
            else
              render_errors(result.error)
            end
          end

          # PATCH /api/v3/storefront/orders/:id/next
          def next
            result = next_service.call(order: @order)

            if result.success?
              render json: serialize_resource(@order)
            else
              render_errors(result.error)
            end
          end

          # PATCH /api/v3/storefront/orders/:id/advance
          def advance
            result = advance_service.call(order: @order)

            if result.success?
              render json: serialize_resource(@order)
            else
              render_errors(result.error)
            end
          end

          # PATCH /api/v3/storefront/orders/:id/complete
          def complete
            result = complete_service.call(order: @order)

            if result.success?
              render json: serialize_resource(@order)
            else
              render_errors(result.error)
            end
          end

          # PATCH /api/v3/storefront/orders/:id/cancel
          def cancel
            @order.cancel!
            render json: serialize_resource(@order)
          rescue StateMachines::InvalidTransition => e
            render_errors(e.message, :unprocessable_entity)
          end

          protected

          def set_order
            @order = Spree::Order.find_by!(number: params[:id])
          end

          def scope
            return Spree::Order.none unless current_user

            current_user.orders.for_store(current_store)
          end

          def model_class
            Spree::Order
          end

          def serializer_class
            Spree::Api::Dependencies.v3_storefront_order_serializer.constantize
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
