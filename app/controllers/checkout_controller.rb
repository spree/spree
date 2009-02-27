class CheckoutController < Spree::BaseController    
  before_filter :require_user_account
  before_filter :load_data
  before_filter :build_object, :except => [:new, :create]

  ssl_required

  resource_controller   
  model_name :checkout_presenter
  object_name :checkout_presenter
         
  create.before do
    # TODO - make sure user is still logged in
    @order.user = current_user       
    @order.ip_address = request.env['REMOTE_ADDR']
  end             

  create.response do |wants|
    wants.html { redirect_to order_url(@order, :checkout_complete => true) }
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
  end
  
  def load_data
    @countries = Country.find(:all)    
    @states = Country.find(214).states.sort
  end
end