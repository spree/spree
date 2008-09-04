class OrdersController < Admin::BaseController
  before_filter :login_required, :except => [:create, :edit]
  layout 'application'
  
  resource_controller

  create.after do    
    # add the specified product to the order
    @order.add_variant(Variant.find(params[:id]))    
    @order.save
  end

  # override the default r_c behavior (remove flash - redirect to edit details instead of show)
  create do
    flash nil 
    wants.html {redirect_to edit_order_url(@order)}
  end
  
  # override the default r_c behavior (r_c doesn't realize we're in a multi step process here)
  edit.before {@order.edit!}
  
  def checkout
    # move into the next checkout state
    if object.checkout_state == "edit"
      object.update_attribute :user, current_user
      object.update_attribute :ip_address, request.env['REMOTE_ADDR']
      object.next! 
    end
    if object.checkout_state == "confirm"
      # remove the order from the session
      session[:order_id] = nil
      redirect_to object_url and return
    else
      next_url = self.send("new_order_#{object.checkout_state}_url", object)
      redirect_to next_url
    end
  end

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
    if params[:id]
      begin
        @order = Order.find params[:id]
      rescue ActiveRecord::RecordNotFound
        @order = find_order
      ensure
        return @order
      end
    end
    find_order
  end
end