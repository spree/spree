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
  edit.before {@order.edit!}
  
  def checkout
    # move into the next checkout state
    object.next! if object.checkout_state == "edit"
    if object.checkout_state == "confirm"
      
    else
      next_url = self.send("new_order_#{object.checkout_state}_url", object)
      redirect_to next_url
    end
  end
=begin    
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
=end

  # override the default r_c behavior (remove flash - redirect to appropriate view based on the checkout_state)
  update.flash nil

  update.response do |wants| 
    #wants.html {redirect_to edit_order_url(object)}
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