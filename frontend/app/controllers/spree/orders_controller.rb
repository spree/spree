module Spree
  class OrdersController < Spree::StoreController
    before_action :set_current_order
    before_action :check_authorization

    helper 'spree/products', 'spree/orders'

    before_action :assign_order_with_lock, only: :update

    def show
      @order = current_store.orders.includes(line_items: [variant: [:option_values, :images, :product]], bill_address: :state, ship_address: :state).find_by!(number: params[:id])
    end

    def update
      @variant = curret_store.variants.find(params[:variant_id]) if params[:variant_id]
      if Cart::Update.call(order: @order, params: order_params).success?
        respond_with(@order) do |format|
          format.html do
            if params.key?(:checkout)
              @order.next if @order.cart?
              redirect_to spree.checkout_state_path(@order.checkout_steps.first)
            else
              redirect_to spree.cart_path
            end
          end
        end
      else
        respond_with(@order)
      end
    end

    # Shows the current incomplete order from the session
    def edit
      @order = current_order || current_store.orders.incomplete.
               includes(line_items: [variant: [:images, :product, option_values: :option_type]]).
               find_or_initialize_by(token: cookies.signed[:token])
      associate_user
    end

    def empty
      cart_empty_service.call(order: current_order)

      redirect_to spree.cart_path
    end

    private

    def accurate_title
      if @order&.completed?
        Spree.t(:order_number, number: @order.number)
      else
        Spree.t(:shopping_cart)
      end
    end

    def check_authorization
      order = current_store.orders.find_by(number: params[:id]) if params[:id].present?
      order ||= current_order

      if order && action_name.to_sym == :show
        authorize! :show, order, cookies.signed[:token]
      elsif order
        authorize! :edit, order, cookies.signed[:token]
      else
        authorize! :create, Spree::Order
      end
    end

    def order_params
      if params[:order]
        params[:order].permit(*permitted_order_attributes)
      else
        {}
      end
    end

    def assign_order_with_lock
      @order = current_order(lock: true)
      unless @order
        flash[:error] = Spree.t(:order_not_found)
        redirect_to root_path and return
      end
    end

    def cart_add_item_service
      Spree::Dependencies.cart_add_item_service.constantize
    end

    def cart_empty_service
      Spree::Dependencies.cart_empty_service.constantize
    end
  end
end
