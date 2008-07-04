class CartController < Spree::BaseController
  before_filter :find_cart
  before_filter :store_previous_location
  
  def index
    @cart_items = @cart.cart_items
    if request.post?
      @cart_items = []
      params[:item].each do |key, values|
        q = values[:quantity]
        if q.to_s == "0"
          CartItem.destroy(key)
        else
          @cart_item = CartItem.find(key)
          @cart_item.update_attributes(values)
          @cart_items << @cart_item
        end
      end
    end
  end
  
  def add
    variant = Variant.find(params[:id])
    item = @cart.add_variant(variant)
    @cart.save
    item.save
    
    redirect_to :action => :index
  end

  def empty
    @cart.cart_items.destroy_all
    redirect_to products_path
  end
  
  private
  def store_previous_location
    session[:PREVIOUS_LOCATION] = nil
    #ignore redirects or direct navigation cases
    return if request.referer.nil? or /cart/.match request.referer
    session[:PREVIOUS_LOCATION] = request.referer
  end  
  
end
