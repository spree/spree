class ShipmentsController < Spree::BaseController
  before_filter :login_required
  before_filter :load_data, :except => :country_changed              
  before_filter :load_shipping_methods, :only => :edit
  before_filter :prevent_orphaned_shipments, :only => [:new, :create] 
  
  resource_controller
  
  belongs_to :order  
  actions :new, :create

  # override r_c defaults so we can handle special presenter logic
  def create        
    build_object
    load_object
    state_check("shipment")  
    unless @shipment_presenter.valid?
      render :action => "new" and return
    end
    @shipment = @order.shipments.new(:address => @shipment_presenter.address)
    # choose first shipping method just as a starting point (user can change in next step)
    @shipment.shipping_method =  @shipment.shipping_methods.first
    @shipment.save
    @order.next!
    redirect_to edit_order_shipment_url(@order, @shipment)
  end

  # override r_c defaults so we can handle special presenter logic
  def update
    if params[:method_id]
      state_check("shipping_method")
      shipping_method = ShippingMethod.find(params[:method_id])
      @shipment.update_attribute(:shipping_method, shipping_method)
      calculator = @shipment.shipping_method.shipping_calculator.constantize.new
      @order.update_attribute(:ship_amount, calculator.calculate_shipping(@shipment))
      @order.next!
    end
    redirect_to checkout_order_url(@order)
  end

  def country_changed
    country_id = params[:shipment_presenter][:address_country_id]
    @states = State.find_all_by_country_id(country_id, :order => 'name')  
    render :partial => "shared/states", :locals => {:presenter_type => "shipment"}
  end  

  private      
  def build_object
    @object ||= end_of_association_chain.send parent? ? :build : :new, object_params     
    if params[:shipment_presenter]
      @shipment_presenter = ShipmentPresenter.new(params[:shipment_presenter]) 
    else
      @shipment_presenter = ShipmentPresenter.new(:address => Address.new(:country_id => @selected_country_id))
    end
  end
  
  def load_data 
    load_object
    @selected_country_id = params[:shipment_presenter][:address_country_id].to_i if params.has_key?('shipment_presenter')
    @selected_country_id ||= Spree::Config[:default_country_id] 
    @states = State.find_all_by_country_id(@selected_country_id, :order => 'name')  
    @countries = @order.shipping_countries 
  end

  def state_check(state)
    if @order.checkout_complete
      # if order has already completed user shouldn't be able to edit shipping information
      redirect_to checkout_order_url(@order) and return 
    else 
      # reset the state to the appropriate value (in case user has hit back button from some other state)
      @order.update_attribute("state", state) unless @order.state == state   
    end
  end

  def prevent_orphaned_shipments
    # right now we assume only one shipment and we're going to clear out any existing (abandoned) shipments
    # in case user has edited cart in the meantime (or perhaps they have started the checkout process over)
    @order.shipments.clear
  end

  def load_shipping_methods
    @shipping_methods = @shipment.shipping_methods
    # check that the rate for each method is available - if we encounter an error, we can inform the user gracefully
    # (instead of having the next view just crash when asked the rate)
    begin
      @shipping_methods.each do |shipping_method|
        rate = shipping_method.calculate_shipping(@shipment)
      end      
    rescue Spree::ShippingError => se
      # We cannot recover from this error (for now.)  Send back to the previous step (and alert the user)
      flash[:error] = se.message
      redirect_to fatal_shipping_order_url(@order)
    end
  end
  
end