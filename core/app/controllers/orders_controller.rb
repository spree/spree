class OrdersController < Spree::BaseController
  ssl_required :show

  helper :products

  def update
    @order = current_order
    if @order.update_attributes(params[:order])
      redirect_to cart_path
    else
      render :edit
    end
  end

  # Shows the current incomplete order from the session
  def edit
    @order = current_order
  end

  # Adds a new item to the order (creating a new order if none already exists)
  #
  # Parameters can be passed using the following possible parameter configurations:
  #
  # * Single variant/quantity pairing
  # +:variants => {variant_id => quantity}+
  #
  # * Multiple products at once (TODO double check this is correct)
  # +:products => {product_id => {variant_id => {:quantity => quantity}, variant_id => {:quantity => quantity}, ...} +
  # +:products => {product_id => {variant_id => {:quantity => [:variant_id => quantity, :variant_id => quantity, ...] }+
  def populate
    @order = current_order(true)
    params[:variants].each do |variant_id, quantity|
      @order.add_variant(Variant.find(variant_id), quantity.to_i) #if quantity > 0
    end if params[:variants]
    redirect_to cart_path
  end

  def empty
    if @order = current_order
      @order.line_items.destroy_all
    end
    redirect_to cart_path
  end

  #
  # def accurate_title
  #   I18n.t(:shopping_cart)
  # end
end
