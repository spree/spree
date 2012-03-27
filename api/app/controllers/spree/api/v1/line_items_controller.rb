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
            invalid_resource!(@line_item)
          end
        end

        def update
          authorize! :read, order
          @line_item = order.line_items.find(params[:id])
          if @line_item.update_attributes(params[:line_item])
            render :show
          else
            invalid_resource!(@line_item)
          end
        end

        def destroy
          authorize! :read, order
          @line_item = order.line_items.find(params[:id])
          @line_item.destroy
          render :text => nil, :status => 200
        end

        private

        def order
          @order ||= Order.find_by_number!(params[:order_id])
        end
      end
    end
  end
end
