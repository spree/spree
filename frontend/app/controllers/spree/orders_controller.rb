module Spree
  class OrdersController < Spree::StoreController
    before_action :check_authorization
    helper 'spree/products', 'spree/orders'

    respond_to :html

    before_action :assign_order_with_lock, only: :update
    skip_before_action :verify_authenticity_token, only: [:populate]

    def show
      @order = Order.includes(line_items: [variant: [:option_values, :images, :product]], bill_address: :state, ship_address: :state).find_by!(number: params[:id])
    end

    def update
      @variant = Spree::Variant.find(params[:variant_id]) if params[:variant_id]
      if Cart::Update.call(order: @order, params: order_params).success?
        respond_with(@order) do |format|
          format.html do
            if params.key?(:checkout)
              @order.next if @order.cart?
              redirect_to checkout_state_path(@order.checkout_steps.first)
            else
              redirect_to cart_path
            end
          end
        end
      else
        respond_with(@order)
      end
    end

    # Shows the current incomplete order from the session
    def edit
      @order = current_order || Order.incomplete.
               includes(line_items: [variant: [:images, :option_values, :product]]).
               find_or_initialize_by(token: cookies.signed[:token])
      associate_user
    end

    # Adds a new item to the order (creating a new order if none already exists)
    def populate
      order    = current_order(create_order_if_necessary: true)
      variant  = Spree::Variant.find(params[:variant_id])
      quantity = params[:quantity].to_i
      options  = params[:options] || {}

      # 2,147,483,647 is crazy. See issue #2695.
      if quantity.between?(1, 2_147_483_647)
        begin
          Spree::Cart::AddItem.call(order: order, variant: variant, quantity: quantity, options: options).value
          order.update_line_item_prices!
          order.create_tax_charge!
          order.update_with_updater!
        rescue ActiveRecord::RecordInvalid => e
          error = e.record.errors.full_messages.join(', ')
        end
      else
        error = Spree.t(:please_enter_reasonable_quantity)
      end

      if error
        flash[:error] = error
        redirect_back_or_default(spree.root_path)
      else
        respond_with(order) do |format|
          format.html { redirect_to(cart_path(variant_id: variant.id)) }
        end
      end
    end

    def populate_redirect
      flash[:error] = Spree.t(:populate_get_error)
      redirect_to cart_path
    end

    def empty
      current_order.try(:empty!)

      redirect_to spree.cart_path
    end

    private

    def accurate_title
      if @order && @order.completed?
        Spree.t(:order_number, number: @order.number)
      else
        Spree.t(:shopping_cart)
      end
    end

    def check_authorization
      order = Spree::Order.find_by(number: params[:id]) if params[:id].present?
      order = current_order unless order

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
  end
end
