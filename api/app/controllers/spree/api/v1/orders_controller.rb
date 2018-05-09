module Spree
  module Api
    module V1
      class OrdersController < Spree::Api::BaseController
        skip_before_action :authenticate_user, only: :apply_coupon_code

        before_action :find_order, except: [:create, :mine, :current, :index, :update, :remove_coupon_code]

        # Dynamically defines our stores checkout steps to ensure we check authorization on each step.
        Order.checkout_steps.keys.each do |step|
          define_method step do
            find_order
            authorize! :update, @order, params[:token]
          end
        end

        def cancel
          authorize! :update, @order, params[:token]
          @order.canceled_by(current_api_user)
          respond_with(@order, default_template: :show)
        end

        def approve
          authorize! :approve, @order, params[:token]
          @order.approved_by(current_api_user)
          respond_with(@order, default_template: :show)
        end

        def create
          authorize! :create, Spree::Order
          if can?(:admin, Spree::Order)
            order_user = if @current_user_roles.include?('admin') && order_params[:user_id]
                          Spree.user_class.find(order_params[:user_id])
                        else
                          current_api_user
            end

            import_params = if @current_user_roles.include?('admin')
                              params[:order].present? ? params[:order].permit! : {}
                            else
                              order_params
                            end

            @order = Spree::Core::Importer::Order.import(order_user, import_params)

            respond_with(@order, default_template: :show, status: 201)
          else
            @order = Spree::Order.create!(user: current_api_user, store: current_store)
            if Cart::Update.call(order: @order, params: order_params).success?
              respond_with(@order, default_template: :show, status: 201)
            else
              invalid_resource!(@order)
            end
          end
        end

        def empty
          authorize! :update, @order, order_token
          @order.empty!
          render plain: nil, status: 204
        end

        def index
          authorize! :index, Order
          @orders = Order.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
          respond_with(@orders)
        end

        def show
          authorize! :show, @order, order_token
          respond_with(@order)
        end

        def update
          find_order(true)
          authorize! :update, @order, order_token

          if Cart::Update.call(order: @order, params: order_params).success?
            user_id = params[:order][:user_id]
            if current_api_user.has_spree_role?('admin') && user_id
              @order.associate_user!(Spree.user_class.find(user_id))
            end
            respond_with(@order, default_template: :show)
          else
            invalid_resource!(@order)
          end
        end

        def current
          @order = find_current_order
          if @order
            respond_with(@order, default_template: :show, locals: { root_object: @order })
          else
            head :no_content
          end
        end

        def mine
          if current_api_user.persisted?
            @orders = current_api_user.orders.reverse_chronological.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
          else
            render 'spree/api/errors/unauthorized', status: :unauthorized
          end
        end

        def apply_coupon_code
          find_order
          authorize! :update, @order, order_token
          @order.coupon_code = params[:coupon_code]
          @handler = PromotionHandler::Coupon.new(@order).apply
          status = @handler.successful? ? 200 : 422
          render 'spree/api/v1/promotions/handler', status: status
        end

        def remove_coupon_code
          find_order(true)
          authorize! :update, @order, order_token
          @handler = Spree::PromotionHandler::Coupon.new(@order).remove(params[:coupon_code])
          status = @handler.successful? ? 200 : 404
          render 'spree/api/v1/promotions/handler', status: status
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
          @order = Spree::Order.lock(lock).find_by!(number: params[:id])
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
