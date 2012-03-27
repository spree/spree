module Spree
  module Api
    module V1
      class LineItemsController < Spree::Api::V1::BaseController
        def create
          authorize! :read, order
          @line_item = order.line_items.build(params[:line_item], :as => :api)
          if @line_item.save
            render :show, :status => 201
          else
            invalid_resource!(@product)
          end
        end

        private

        def order
          @order ||= Order.find_by_number!(params[:order_id])
        end
      end
    end
  end
end
