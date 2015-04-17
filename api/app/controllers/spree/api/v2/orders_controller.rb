module Spree
  module Api
    module V2
      class OrdersController < Spree::Api::BaseController
        skip_before_action :check_for_user_or_api_key, only: :apply_coupon_code
        skip_before_action :authenticate_user, only: :apply_coupon_code

        before_action :find_order, except: [:create, :mine, :current, :index, :update]

        # Dynamically defines our stores checkout steps to ensure we check authorization on each step.
        Order.checkout_steps.keys.each do |step|
          define_method step do
            find_order
            authorize! :update, @order, params[:token]
          end
        end

        def cancel
          authorize! :update, @order, params[:token]
          @order.cancel!
          render json: @order
        end

        def create
          authorize! :create, Order
          order_user = if @current_user_roles.include?('admin') && order_params[:user_id]
            Spree.user_class.find(order_params[:user_id])
          else
            current_api_user
          end

          import_params = if @current_user_roles.include?("admin")
            params[:order].present? ? params[:order].permit! : {}
          else
            order_params
          end

          @order = Spree::Core::Importer::Order.import(order_user, import_params)
          render json: @order, status: 201
        end

        def empty
          authorize! :update, @order, order_token
          @order.empty!
          render nothing: true, status: 204
        end

        def index
          authorize! :index, Order
          @orders = Order.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
          render json: @orders, meta: pagination(@orders)
        end

        def show
          authorize! :show, @order, order_token
          render json: @order
        end

        def update
          find_order(true)
          authorize! :update, @order, order_token

          if @order.contents.update_cart(order_params)
            user_id = params[:order][:user_id]
            if current_api_user.has_spree_role?('admin') && user_id
              @order.associate_user!(Spree.user_class.find(user_id))
            end
            render json: @order
          else
            invalid_resource!(@order)
          end
        end

        def current
          @order = find_current_order
          if @order
            render json: @order
          else
            head :no_content
          end
        end

        def mine
          if current_api_user.persisted?
            @orders = current_api_user.orders.reverse_chronological.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
            render json: @orders, meta: pagination(@orders)
          else
            unauthorized
          end
        end

        def apply_coupon_code
          find_order
          authorize! :update, @order, order_token
          @order.coupon_code = params[:coupon_code]
          @handler = PromotionHandler::Coupon.new(@order).apply
          status = @handler.successful? ? 200 : 422
          render json: {
            success: @handler.success,
            error: @handler.error,
            successful: @handler.successful?,
            status_code: @handler.status_code
          }, status: status
        end

        private
          def order_params
            if params[:order]
              normalize_params
              params.require(:order).permit(permitted_order_attributes)
            else
              {}
            end
          end

          def normalize_params
            params[:order][:payments_attributes] = params[:order].delete(:payments) if params[:order][:payments]
            params[:order][:shipments_attributes] = params[:order].delete(:shipments) if params[:order][:shipments]
            params[:order][:line_items_attributes] = params[:order].delete(:line_items) if params[:order][:line_items]
            params[:order][:ship_address_attributes] = params[:order].delete(:ship_address) if params[:order][:ship_address]
            params[:order][:bill_address_attributes] = params[:order].delete(:bill_address) if params[:order][:bill_address]
          end

          def find_order(lock = false)
            @order = Spree::Order.lock(lock).friendly.find(params[:id])
          end

          def find_current_order
            current_api_user ? current_api_user.orders.incomplete.order(:created_at).last : nil
          end

          def order_id
            super || params[:id]
          end
      end
    end
  end
end
