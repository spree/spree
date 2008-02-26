class StoreController < RailsCart::BaseController
  before_filter :find_cart

  def index
    list
    render :action => 'list'
  end
  
  # list products in the store
  # TODO: add constraints to the find based on category, etc.
  def list
    @products = Product.find(:all, :page => {:start => 1, :size => 15})
    @product_cols = 3
  end
  
  def show
    @product = Product.find(params[:id])
  end
  
  # AJAX method
  def change_image
    @product = Product.find(params[:id])
    img = Image.find(params[:image_id])
    render :partial => 'image', :locals => {:image => img}
  end

end
