class OrdersController < Spree::BaseController
  before_filter :require_user_account, :only => [:checkout]
  before_filter :load_object, :only => [:checkout]          
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
                                                                           
  edit.before { @order.edit! }
  
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
    return if logged_in?
    store_location
    redirect_to signup_path 
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
    redirect_to object_url unless @order.can_edit?
  end
end
