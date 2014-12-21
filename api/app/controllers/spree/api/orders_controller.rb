module Spree
  module Api
    class OrdersController < Spree::Api::BaseController

      skip_before_filter :check_for_user_or_api_key, only: :apply_coupon_code
      skip_before_filter :authenticate_user, only: :apply_coupon_code

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
        authorize! :update, @order, order_token
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
        authorize! :show, @order, order_token
        method = "before_#{@order.state}"
        send(method) if respond_to?(method, true)
        respond_with(@order)
      end

      def update
        find_order(true)
        authorize! :update, @order, order_token
        # Parsing line items through as an update_attributes call in the API will result in
        # many line items for the same variant_id being created. We must be smarter about this,
        # hence the use of the update_line_items method, defined within order_decorator.rb.
        order_params.delete("line_items_attributes")
        if @order.update_attributes(order_params)

          deal_with_line_items if params[:order][:line_items]

          @order.line_items.reload
          @order.update!
          respond_with(@order, default_template: :show)
        else
          invalid_resource!(@order)
        end
      end
      
      def mine
        if current_api_user.persisted?
          @orders = current_api_user.orders.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
        else
          render "spree/api/errors/unauthorized", status: :unauthorized
        end
      end

      ##
      # Applies a promotion code to the user's most recent order
      # This is a temporary API method until we move to next Spree release which has this logic already in this commit.
      #
      # https://github.com/spree/spree/commit/72a5b74c47af975fc3492580415a4cdc2dc02c0c 
      #
      # Source references:
      #
      # https://github.com/spree/spree/blob/master/frontend/app/controllers/spree/store_controller.rb#L13
      # https://github.com/spree/spree/blob/2-1-stable/frontend/app/controllers/spree/orders_controller.rb#L100
      def apply_coupon_code
        find_order
        authorize! :update, @order, order_token
        @order.coupon_code = params[:coupon_code]
        @order.save

        # https://github.com/spree/spree/blob/2-1-stable/core/lib/spree/promo/coupon_applicator.rb
        result = Spree::Promo::CouponApplicator.new(@order).apply

        result[:coupon_applied?]  ||= false

        # Move flash.notice fields into success if applied
        # An error message is in result[:error]
        if result[:coupon_applied?] && result[:notice]
          result[:success] = result[:notice]
        end

        # Need to turn hash result into object for RABL
        # https://github.com/nesquena/rabl/wiki/Rendering-hash-objects-in-rabl
        @coupon_result = OpenStruct.new(result)
        render status: @coupon_result.coupon_applied? ? 200 : 422
      end

      private
        def deal_with_line_items
          line_item_attributes = params[:order][:line_items]
          line_item_attributes.each_key do |key|
            # need to call .to_hash to make sure Rails 4's strong parameters don't bite
            line_item_attributes[key] = line_item_attributes[key].slice(*permitted_line_item_attributes).to_hash
          end
          @order.update_line_items(line_item_attributes)
        end

        def order_params
          if params[:order]
            params[:order][:payments_attributes] = params[:order][:payments] if params[:order][:payments]
            params[:order][:shipments_attributes] = params[:order][:shipments] if params[:order][:shipments]
            params[:order][:line_items_attributes] = params[:order][:line_items] if params[:order][:line_items]
            params[:order][:ship_address_attributes] = params[:order][:ship_address] if params[:order][:ship_address]
            params[:order][:bill_address_attributes] = params[:order][:bill_address] if params[:order][:bill_address]

            params.require(:order).permit(permitted_order_attributes)
          else
            {}
          end
        end

        def permitted_order_attributes
          if current_api_user.has_spree_role? "admin"
            super + admin_order_attributes
          else
            super
          end
        end

        def permitted_shipment_attributes
          if current_api_user.has_spree_role? "admin"
            super + admin_shipment_attributes
          else
            super
          end
        end

        def admin_shipment_attributes
          [:shipping_method, :stock_location, :inventory_units => [:variant_id, :sku]]
        end

        def admin_order_attributes
          [:import, :number, :completed_at, :locked_at, :channel]
        end

        def next!(options={})
          if @order.valid? && @order.next
            render :show, status: options[:status] || 200
          else
            render :could_not_transition, status: 422
          end
        end

        def find_order(lock = false)
          @order = Spree::Order.lock(lock).find_by!(number: params[:id])
        end

        def before_delivery
          @order.create_proposed_shipments
        end
    end
  end
end
