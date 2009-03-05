class OrdersController < Spree::BaseController
#  before_filter :load_object, :only => [:checkout]          
  before_filter :prevent_editing_complete_order, :only => [:edit, :update]            

  ssl_required :show

  resource_controller
  actions :all, :except => :index

  layout 'application'
  
  helper :products

  create.after do    
    # add the specified products in given quantities to the order
    # the information is specified in a hash.
    
    params[:quantities].each do |product_id,vq|
      (variant_id,quantity) = vq.split '='
      quantity = quantity.to_i
      @order.add_variant(Variant.find(variant_id), quantity) if quantity > 0
    end
    @order.save
  end

  # override the default r_c behavior (remove flash - redirect to edit details instead of show)
  create do
    flash nil 
    wants.html {redirect_to edit_order_url(@order)}
  end
  
  # override the default r_c flash behavior
  update.flash nil
  update.response do |wants| 
    wants.html {redirect_to edit_order_url(object)}
  end  

  destroy do
    flash nil 
    wants.html {redirect_to new_order_url}
  end
    
  private
  def build_object        
    find_order
  end
  
  def object
    if params[:id]
      begin
        @order = Order.find_by_param! params[:id]
      rescue ActiveRecord::RecordNotFound
        @order = find_order
      ensure
        return @order
      end
    end
    find_order
  end   
  
  def prevent_editing_complete_order
    redirect_to object_url if @order.checkout_complete
  end
end
