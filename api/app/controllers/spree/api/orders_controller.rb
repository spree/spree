module Spree
  module Api
    class OrdersController < Spree::Api::BaseController

      # Dynamically defines our stores checkout steps to ensure we check authorization on each step.
      Order.checkout_steps.keys.each do |step|
        define_method step do
          find_order
          authorize! :update, @order, params[:token]
        end
      end

      def cancel
        find_order
        authorize! :update, @order, params[:token]
        @order.cancel!
        render :show
      end

      def create
        authorize! :create, Order
        @order = Order.build_from_api(current_api_user, nested_params)
        respond_with(@order, :default_template => :show, :status => 201)
      end

      def empty
        find_order
        @order.line_items.destroy_all
        @order.update!
        render :text => nil, :status => 200
      end

      def index
        authorize! :index, Order
        @orders = Order.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
        respond_with(@orders)
      end

      def show
        find_order
        respond_with(@order)
      end

      def update
        find_order
        # Parsing line items through as an update_attributes call in the API will result in
        # many line items for the same variant_id being created. We must be smarter about this,
        # hence the use of the update_line_items method, defined within order_decorator.rb.
        order_params = nested_params
        line_items = order_params.delete("line_items_attributes")
        if @order.update_attributes(order_params)
          @order.update_line_items(line_items)
          @order.update!
          respond_with(@order, :default_template => :show)
        else
          invalid_resource!(@order)
        end
      end

      private

      def nested_params
        map_nested_attributes_keys Order, params[:order] || {}
      end

      def next!(options={})
        if @order.valid? && @order.next
          render :show, :status => options[:status] || 200
        else
          render :could_not_transition, :status => 422
        end
      end

      def find_order
        @order = Order.find_by_number!(params[:id])
        authorize! :update, @order, params[:order_token]
      end

    end
  end
end
