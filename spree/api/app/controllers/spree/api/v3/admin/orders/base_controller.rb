module Spree
  module Api
    module V3
      module Admin
        module Orders
          class BaseController < ResourceController
            include Spree::Api::V3::OrderLock

            before_action :authorize_order_access!

            protected

            def set_parent
              @parent = current_store.orders.find_by_prefix_id!(params[:order_id])
              @order = @parent
            end

            def authorize_order_access!
              authorize!(:show, @parent)
            end
          end
        end
      end
    end
  end
end
