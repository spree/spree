class CheckoutController < Spree::BaseController                 
  before_filter :stop_monkey_business, :except => :cvv
  before_filter :require_user_account
  before_filter :load_data, :except => :cvv
  before_filter :build_object, :except => [:new, :create, :cvv]

  ssl_required :new, :create

  resource_controller   
  model_name :checkout_presenter
  object_name :checkout_presenter

  # modified version of r_c create method (easier then all the before after hooks - especially for gateway error handling)
  def create
    build_object
    load_object

    @order.user = current_user       
    @order.ip_address = request.env['REMOTE_ADDR']
    
    begin
      if object.save
        # remove the order from the session
        session[:order_id] = nil if @order.checkout_complete  
      else
        flash[:error] = t("unable_to_save_order")
        render :action => "new" and return
      end       
    rescue Spree::GatewayError => ge
      flash.now[:error] = t("unable_to_authorize_credit_card") + ": #{ge.message}"
      render :action => "new" and return 
    end
        
    respond_to do |format|
      format.html {redirect_to order_url(@order, :checkout_complete => true) }
      format.js {render :json => { :order => @checkout_presenter.order_hash, 
                                   :available_methods => @order.shipment.rates }.to_json,
                        :layout => false}
    end
    
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
    if params[:checkout_presenter]
      @object ||= end_of_association_chain.send parent? ? :build : :new, params[:checkout_presenter]  
    else                       
      # user has not yet submitted checkout parameters, we can use defaults of current_user and order objects
      bill_address = current_user.last_address unless current_user == :false
      bill_address ||= Address.new
      ship_address = @order.ship_address || Address.new
      shipping_method = @order.shipment ? @order.shipment.shipping_method : nil
      @object ||= end_of_association_chain.send parent? ? :build : :new, {:bill_address => bill_address, 
                                                                          :ship_address => ship_address, 
                                                                          :shipping_method => shipping_method }
    end     
    @object.final_answer = params[:final_answer] unless params[:final_answer].blank? 
    @object.order = @order      
    @object.shipping_method = ShippingMethod.find_by_id(params[:method_id]) if params[:method_id]        
  end
  
  def load_data
    @countries = Country.find(:all).sort  
    @shipping_countries = @object.order.shipping_countries.sort  
    @states = Country.find(214).states.sort

    month = @object.creditcard.month ? @object.creditcard.month.to_i : Date.today.month
    year = @object.creditcard.year ? object.creditcard.year.to_i : Date.today.year
    @date = Date.new(year, month, 1)
  end 
  
  def stop_monkey_business
    build_object
    redirect_to order_url(@order) and return if @order.checkout_complete    
  end
end
