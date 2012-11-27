module Spree
  class OrdersController < Spree::StoreController
    ssl_required :show

    rescue_from ActiveRecord::RecordNotFound, :with => :render_404
    helper 'spree/products'

    respond_to :html

    def show
      @order = Order.find_by_number!(params[:id])
      respond_with(@order)
    end

    def update
      @order = current_order
      if @order.update_attributes(params[:order])
        @order.line_items = @order.line_items.select {|li| li.quantity > 0 }
        fire_event('spree.order.contents_changed')
        respond_with(@order) do |format|
          format.html do
            if params.has_key?(:checkout)
              @order.next_transition.run_callbacks
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
    #
    # Parameters can be passed using the following possible parameter configurations:
    #
    # * Single variant/quantity pairing
    # +:variants => { variant_id => quantity }+
    #
    # * Multiple products at once
    # +:products => { product_id => variant_id, product_id => variant_id }, :quantity => quantity+
    # +:products => { product_id => variant_id, product_id => variant_id }, :quantity => { variant_id => quantity, variant_id => quantity }+
    def populate
      @order = current_order(true)

      params[:products].each do |product_id,variant_id|
        quantity = params[:quantity].to_i if !params[:quantity].is_a?(Hash)
        quantity = params[:quantity][variant_id].to_i if params[:quantity].is_a?(Hash)
        @order.add_variant(Variant.find(variant_id), quantity, current_currency) if quantity > 0
      end if params[:products]

      params[:variants].each do |variant_id, quantity|
        quantity = quantity.to_i
        @order.add_variant(Variant.find(variant_id), quantity, current_currency) if quantity > 0
      end if params[:variants]

      fire_event('spree.cart.add')
      fire_event('spree.order.contents_changed')
      respond_with(@order) { |format| format.html { redirect_to cart_path } }
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
