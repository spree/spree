module Spree
  module Api
    module V3
      module Store
        class OrdersController < Store::BaseController
          # GET /api/v3/store/orders/:id
          # Single order lookup — accessible via order token (guests) or JWT (authenticated users)
          before_action :find_order!

          def show
            render json: serializer_class.new(@order, params: serializer_params).to_h
          end

          private

          def find_order!
            @order = scope.find_by_prefix_id!(params[:id])
            authorize!(:show, @order, order_token)
          end

          def scope
            base = current_store.orders.complete

            if current_user.present?
              base.where(user: current_user)
            elsif order_token.present?
              base.where(token: order_token)
            else
              base.none
            end
          end

          def serializer_class
            Spree.api.order_serializer
          end

          def order_token
            request.headers['x-spree-token']
          end
        end
      end
    end
  end
end
