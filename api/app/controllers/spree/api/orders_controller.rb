module Spree
  module Api
    class OrdersController < Spree::Api::BaseController

      # Dynamically defines our stores checkout steps to ensure we check authorization on each step.
      Order.checkout_steps.keys.each do |step|
        define_method step do
          authorize! :update, @order
        end
      end

      def cancel
        @order = Order.find_by_number!(params[:id])
        authorize! :update, @order
        @order.cancel!
        render :show
      end

      def create
        authorize! :create, Order
        @order = Order.build_from_api(current_api_user, nested_params)
        respond_with(@order, :default_template => :show, :status => 201)
      end

      def empty
        @order = Order.find_by_number!(params[:id])
        authorize! :update, @order
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
        @order = Order.find_by_number!(params[:id])
        authorize! :read, @order
        respond_with(@order)
      end

      def update
        @order = Order.find_by_number!(params[:id])
        authorize! :update, @order
        if @order.update_attributes(nested_params)
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

    end
  end
end
