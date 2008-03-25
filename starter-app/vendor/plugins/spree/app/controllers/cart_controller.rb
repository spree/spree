class CartController < Spree::BaseController
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
    variant_id = params[:variant_id]
    if variant_id.blank? 
      variant = nil
    else
      variant = Variant.find(variant_id)
    end
    item = @cart.add_product(product, variant)
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
