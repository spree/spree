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
        @order = Order.build_from_api(current_api_user, order_params)
        respond_with(@order, default_template: :show, status: 201)
      end

      def empty
        find_order
        @order.empty!
        @order.update!
        render text: nil, status: 200
      end

      def index
        authorize! :index, Order
        @orders = Order.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
        respond_with(@orders)
      end

      def show
        find_order
        method = "before_#{@order.state}"
        send(method) if respond_to?(method, true)
        respond_with(@order)
      end

      def update
        find_order
        # Parsing line items through as an update_attributes call in the API will result in
        # many line items for the same variant_id being created. We must be smarter about this,
        # hence the use of the update_line_items method, defined within order_decorator.rb.
        order_params.delete("line_items_attributes")
        if @order.update_attributes(order_params)
          @order.update_line_items(params[:order][:line_items])
          @order.line_items.reload
          @order.update!
          respond_with(@order, default_template: :show)
        else
          invalid_resource!(@order)
        end
      end

      def apply_coupon_code
        find_order
        @order.coupon_code = params[:coupon_code]
        @handler = PromotionHandler::Coupon.new(@order).apply
        status = @handler.successful? ? 200 : 422
        render "spree/api/promotions/handler", :status => status
      end

      private

        def order_params
          if params[:order]
            params[:order][:line_items_attributes] = params[:order][:line_items]
            params[:order][:ship_address_attributes] = params[:order][:ship_address] if params[:order][:ship_address]
            params[:order][:bill_address_attributes] = params[:order][:bill_address] if params[:order][:bill_address]
            params.require(:order).permit(permitted_order_attributes)
          else
            {}
          end
        end

        def next!(options={})
          if @order.valid? && @order.next
            render :show, status: options[:status] || 200
          else
            render :could_not_transition, status: 422
          end
        end

        def find_order
          @order = Spree::Order.find_by!(number: params[:id])
          authorize! :update, @order, params[:order_token]
        end

        def before_delivery
          @order.create_proposed_shipments
        end

    end
  end
end
