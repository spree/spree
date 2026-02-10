module Spree
  module Api
    module V3
      module Store
        module Orders
          class StoreCreditsController < Store::BaseController
            include Spree::Api::V3::OrderConcern
            include Spree::Api::V3::ResourceSerializer

            before_action :require_authentication!
            before_action :set_parent
            before_action :authorize_order_access!

            # POST /api/v3/store/orders/:order_id/store_credits
            def create
              result = Spree.checkout_add_store_credit_service.call(
                order: @parent,
                amount: params[:amount].try(:to_f)
              )

              if result.success?
                render json: serialize_resource(@parent.reload)
              else
                render_service_error(result.error)
              end
            end

            # DELETE /api/v3/store/orders/:order_id/store_credits
            def destroy
              result = Spree.checkout_remove_store_credit_service.call(order: @parent)

              if result.success?
                render json: serialize_resource(@parent.reload)
              else
                render_service_error(result.error)
              end
            end

            protected

            def serializer_class
              Spree.api.order_serializer
            end
          end
        end
      end
    end
  end
end
