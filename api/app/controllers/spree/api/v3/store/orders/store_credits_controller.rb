module Spree
  module Api
    module V3
      module Store
        module Orders
          class StoreCreditsController < Store::BaseController
            include Spree::Api::V3::OrderConcern
            include Spree::Api::V3::ResourceSerializer

            before_action :require_authentication!
            before_action :set_order

            # POST /api/v3/store/orders/:order_id/store_credits
            def create
              result = Spree.checkout_add_store_credit_service.call(
                order: @order,
                amount: params[:amount].try(:to_f)
              )

              if result.success?
                render json: serialize_resource(@order.reload)
              else
                render_service_error(result.error)
              end
            end

            # DELETE /api/v3/store/orders/:order_id/store_credits
            def destroy
              result = Spree.checkout_remove_store_credit_service.call(order: @order)

              if result.success?
                render json: serialize_resource(@order.reload)
              else
                render_service_error(result.error)
              end
            end

            protected

            def set_order
              @order = current_store.orders.friendly.find(params[:order_id])
              authorize!(:update, @order, order_token)
            end

            def serializer_class
              Spree.api.order_serializer
            end
          end
        end
      end
    end
  end
end
