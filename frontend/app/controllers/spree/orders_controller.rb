module Spree
  class OrdersController < Spree::StoreController
    ssl_required :show

    rescue_from ActiveRecord::RecordNotFound, :with => :render_404
    helper 'spree/products', 'spree/orders'

    respond_to :html

    def show
      @order = Order.find_by_number!(params[:id])
    end

    def update
      @order = current_order
      if @order.update_attributes(params[:order])
        render :edit and return unless apply_coupon_code
        @order.line_items = @order.line_items.select {|li| li.quantity > 0 }
        fire_event('spree.order.contents_changed')
        if params.has_key?(:checkout)
          @order.next_transition.run_callbacks
          redirect_to checkout_state_path(@order.checkout_steps.first)
        else
          redirect_to cart_path
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
      @order && @order.completed? ? "#{Order.model_name.human} #{@order.number}" : t(:shopping_cart)
    end
  end
end
