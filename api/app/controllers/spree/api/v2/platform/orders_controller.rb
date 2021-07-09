module Spree
  module Api
    module V2
      module Platform
        class OrdersController < ResourceController
          before_action -> { doorkeeper_authorize! :write, :admin }, only: WRITE_ACTIONS << :advance
          before_action :find_order

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

          def find_order
            @order = model_class.find_by(number: params[:id])
          end

          def advance_service
            Spree::Api::Dependencies.storefront_checkout_advance_service.constantize
          end
        end
      end
    end
  end
end
