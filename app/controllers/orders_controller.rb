class OrdersController < Admin::BaseController
  layout 'application'
  
  resource_controller
  actions :show, :create, :edit, :update

  create.after do    
    # add the specified product to the order
    @order.add_variant(Variant.find(params[:id]))    
    @order.save
  end

  # override the default r_c behavior (remove flash - redirect to line items instead of order)
  create do
    flash nil 
    wants.html {redirect_to edit_order_url(@order)}
  end
  
  private
  def build_object        
    find_order
  end
  
  def object
    find_order
  end
end