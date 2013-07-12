module Spree
  class OrdersController < Spree::StoreController
    ssl_required :show

    before_filter :check_authorization
    rescue_from ActiveRecord::RecordNotFound, :with => :render_404
    helper 'spree/products', 'spree/orders'

    respond_to :html

    def show
      @order = Order.find_by_number!(params[:id])
    end

    def update
      @order = current_order
      unless @order
        flash[:error] = Spree.t(:order_not_found)
        redirect_to root_path and return
      end

      if @order.update_attributes(params[:order])
        @order.line_items = @order.line_items.select {|li| li.quantity > 0 }
        @order.ensure_updated_shipments
        return if after_update_attributes

        fire_event('spree.order.contents_changed')

        respond_with(@order) do |format|
          format.html do
            if params.has_key?(:checkout)
              @order.next_transition.run_callbacks if @order.cart?
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
      @order = current_order(true)
      associate_user
    end

    # Adds a new item to the order (creating a new order if none already exists)
    def populate
      populator = Spree::OrderPopulator.new(current_order(true), current_currency)
      if populator.populate(params.slice(:products, :variants, :quantity))
        current_order.ensure_updated_shipments

        fire_event('spree.cart.add')
        fire_event('spree.order.contents_changed')
        respond_with(@order) do |format|
          format.html { redirect_to cart_path }
        end
      else
        flash[:error] = populator.errors.full_messages.join(" ")
        redirect_to :back
      end
    end

    def empty
      if @order = current_order
        @order.empty!
      end

      redirect_to spree.cart_path
    end

    def accurate_title
      @order && @order.completed? ? "#{Spree.t(:order)} #{@order.number}" : Spree.t(:shopping_cart)
    end

    def check_authorization
      session[:access_token] ||= params[:token]
      order = Spree::Order.find_by_number(params[:id]) || current_order

      if order
        authorize! :edit, order, session[:access_token]
      else
        authorize! :create, Spree::Order
      end
    end

    private

    def after_update_attributes
      coupon_result = Spree::Promo::CouponApplicator.new(@order).apply
      if coupon_result[:coupon_applied?]
        flash[:success] = coupon_result[:success] if coupon_result[:success].present?
        return false
      else
        flash[:error] = coupon_result[:error]
        respond_with(@order) { |format| format.html { render :edit } }
        return true
      end
    end
  end
end
