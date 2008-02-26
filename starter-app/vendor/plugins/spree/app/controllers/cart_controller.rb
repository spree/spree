class CartController < RailsCart::BaseController
  before_filter :find_cart
  before_filter :store_previous_location
  
  def index
    if request.post?
      params[:item].each do |key, values|
        if values[:quantity].to_i == 0
          CartItem.destroy(key)
        else
          CartItem.update(key, values)
        end
      end
    end
  end
  
  def add
    product = Product.find(params[:product][:id])
    variation_id = params[:variation_id]
    if variation_id.blank? 
      variation = nil
    else
      variation = Variation.find(variation_id)
    end
    item = @cart.add_product(product, variation)
    @cart.save
    item.save
    
    redirect_to :action => :index
  end

  def empty
    @cart.cart_items.destroy_all
    redirect_to :controller => :store, :action => :index
  end
  
  private
  def store_previous_location
    session[:PREVIOUS_LOCATION] = nil
    #ignore redirects or direct navigation cases
    return if request.referer.nil? or /cart/.match request.referer
    session[:PREVIOUS_LOCATION] = request.referer
  end  
  
end
