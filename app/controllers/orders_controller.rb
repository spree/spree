class OrdersController < Admin::BaseController
  layout 'application'
  
  resource_controller
  #actions :show, :create, :edit, :update

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
  
  # override the default r_c behavior (r_c doesn't realize we're in a multi step process here)
  #edit.before {@order.edit!}
  edit.wants.html {render :action => "states/editing"}
  edit.response do |wants| 
    wants.html {render :action => "states/#{@order.checkout_state}"}
  end
  
  def checkout
    # move into the 2nd checkout state (unless we're already in the 2nd or later state)
    object.next! if object.checkout_state == "editing"
    redirect_to edit_order_url(object)
  end
  
  update.after do 
    transition = params[:transition] 
    transition_method = "#{transition}!" unless transition.blank?
    @order.send(transition_method) if transition_method
    if @order.checkout_state == "confirming"
      @order.user = current_user
      @order.save
      session[:order_id] = nil 
    end
  end

  # override the default r_c behavior (remove flash - redirect to appropriate view based on the checkout_state)
  update.flash nil
  update.response do |wants| 
    wants.html {redirect_to edit_order_url(object)}
    #wants.html {render :action => "states/#{@order.checkout_state}"}
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
    find_order
  end
end