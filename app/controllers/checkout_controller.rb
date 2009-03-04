class CheckoutController < Spree::BaseController    
  before_filter :require_user_account
  before_filter :load_data
  before_filter :build_object, :except => [:new, :create]

  ssl_required

  resource_controller   
  model_name :checkout_presenter
  object_name :checkout_presenter
         
  create.before do
    @order.user = current_user       
    @order.ip_address = request.env['REMOTE_ADDR']
  end             

  create do
    flash nil 
    wants.html {redirect_to order_url(@order, :checkout_complete => true) }
    #wants.json {render :json => @order.to_json, :layout => false}
    wants.json {render :json => { :order => @order, 
                                  :available_methods => @order.shipment.rates }.to_json,
                       :layout => false} 
  end

  create.after do  
    # remove the order from the session
    session[:order_id] = nil if @order.checkout_complete
  end
  
  def cvv
    render :layout => false
  end  
         
  def select_country         
    @states = @object.bill_address.country.states#, :order => 'name')  
    respond_to do |format|
      format.js
    end
  end
  
  protected
  def require_user_account
    return if logged_in?
    store_location
    redirect_to signup_path 
  end
  
  private
  def build_object
    @order = Order.find_by_number(params[:order_number])
    @object ||= end_of_association_chain.send parent? ? :build : :new, params[:checkout_presenter]
    @object.order = @order      
    @object.shipping_method = ShippingMethod.find_by_id(params[:method_id]) 
  end
  
  def load_data
    @countries = Country.find(:all)    
    @states = Country.find(214).states.sort
  end
end