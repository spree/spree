class OrdersController < Spree::BaseController
  before_filter :require_user_account, :only => [:checkout]
  before_filter :load_object, :only => [:checkout]

  ssl_required :show

  resource_controller
  actions :all, :except => [:index, :destroy]

  layout 'application'
  
  helper :products

  create.after do    
    # add the specified product to the order
    @order.add_variant(Variant.find(params[:variant][:id]))
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
    if @order.state == "in_progress"
      @order.update_attribute :user, current_user
      @order.update_attribute :ip_address, request.env['REMOTE_ADDR']
      @order.next! 
    end
    if object.checkout_complete
      # remove the order from the session
      session[:order_id] = nil
      redirect_to object_url(:checkout_complete => true) and return
    else
      # note: controllers participating in checkout process are responsible for calling Order#next! 
      next_url = self.send("new_order_#{object.state}_url", @order)
      redirect_to next_url
    end
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

  protected
  def require_user_account
    redirect_to signup_path unless logged_in?
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