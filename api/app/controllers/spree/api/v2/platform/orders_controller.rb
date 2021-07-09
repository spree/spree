module Spree
  module Api
    module V2
      module Platform
        class OrdersController < ResourceController
          before_action -> { doorkeeper_authorize! :write, :admin }, only: WRITE_ACTIONS << :advance
          before_action :load_order_with_lock, only: [:advance]

          include Spree::Api::V2::Storefront::OrderConcern

          def advance
            spree_authorize! :update, @order if spree_current_user.present?

            result = advance_service.call(order: @order)

            render_order(result)
          end

          private

          def model_class
            Spree::Order
          end

          def scope_includes
            [:line_items]
          end

          def load_order(lock: false)
            @order = Spree::Order.lock(lock).find_by!(number: params[:id])
          end

          def load_order_with_lock
            load_order(lock: true)
          end

          def advance_service
            Spree::Api::Dependencies.storefront_checkout_advance_service.constantize
          end
        end
      end
    end
  end
end
