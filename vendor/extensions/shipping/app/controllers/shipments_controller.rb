class ShipmentsController < Spree::BaseController
  before_filter :login_required
  before_filter :load_data, :except => :country_changed
  before_filter :state_check, :except => [:shipping_method, :country_changed]
  before_filter :remove_existing, :only => :new
  before_filter :validate_shipment, :only => [:create, :update]
  
  resource_controller
  belongs_to :order
  
  # override r_c defaults so we can handle special presenter logic
  def create
    @shipment = @order.shipments.create(:address => @shipment_presenter.address)
    @order.next!
    redirect_to shipping_method_order_shipment_url(@order, @shipment)
  end

  def shipping_method
    state_check 'shipping_method'
    load_shipping_methods
  end
  
  def country_changed
    country_id = params[:shipment_presenter][:address_country_id]
    @states = State.find_all_by_country_id(country_id, :order => 'name')  
    render :partial => "shared/states"
  end  

  # override r_c defaults so we can handle special presenter logic
  def update
    if @shipment_presenter
      @shipment.update_attribute(:address, @shipment_presenter.address)
      # note: we can reach update from two different views (edit and shipping_method)
      @order.next!
      redirect_to shipping_method_order_shipment_url(@order, @shipment)
      return
    end
    if params[:method_id]
      state_check("shipping_method")
      shipping_method = ShippingMethod.find(params[:method_id])
      @shipment.update_attribute(:shipping_method, shipping_method)
      calculator = @shipment.shipping_method.shipping_calculator.constantize.new
      @order.update_attribute(:ship_amount, calculator.calculate_shipping(@shipment))
    end
    @order.next!
    redirect_to checkout_order_url(@order)
  end

  private
  def object
    return find_shipment if param.blank?
    @object ||= end_of_association_chain.find(param) unless param.nil?
  end

  def load_data 
    load_object
    @selected_country_id = params[:shipment_presenter][:address_country_id].to_i if params.has_key?('shipment_presenter')
    @selected_country_id ||= Spree::Config[:default_country_id] 
    @states = State.find_all_by_country_id(@selected_country_id, :order => 'name')  
    @countries = Country.find(:all)
  end
  
  def find_shipment
    @object = parent_object.shipments.last
    @object ||= Shipment.new(:order => parent_object)
  end

  def state_check(state="shipment")
    if @order.checkout_complete
      # if order has already completed user shouldn't be able to edit shipping information
      redirect_to checkout_order_url(@order) and return 
    end
    # reset the state to the appropriate value (in case user has hit back button from some other state)
    @order.update_attribute(:state, state)
  end

  def remove_existing
    # right now we assume only one shipment and we're going to clear out any existing (abandoned) shipments
    # in case user has edited cart in the meantime
    @order.shipments.clear
  end
  
  def validate_shipment
    return unless params[:shipment_presenter]
    @shipment_presenter = ShipmentPresenter.new(params[:shipment_presenter]) 
    render :action => "new" unless @shipment_presenter.valid?
  end
  
  def load_shipping_methods
    @shipping_methods = @shipment.shipping_methods
    # check that the rate for each method is available - if we encounter an error, we can inform the user gracefully
    # (instead of having the next view just crash when asked the rate)
    begin
      @shipping_methods.each do |shipping_method|
        rate = shipping_method.calculate_shipping(@shipment)
        @default_method ||= shipping_method unless rate.nil?
      end      
    rescue Spree::ShippingError => se
      # We cannot recover from this error (for now.)  Send back to the previous step (and alert the user)
      flash[:error] = se.message
      redirect_to fatal_shipping_order_url(@order)
    end
  end
  
end