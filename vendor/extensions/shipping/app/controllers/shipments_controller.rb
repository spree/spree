class ShipmentsController < Admin::BaseController
  before_filter :login_required
  before_filter :state_check
  before_filter :check_existing, :only => :new
  layout 'application'
  
  resource_controller
  belongs_to :order
  
  create.response do |wants|
    wants.html do 
      next_step
    end
  end
  
  create.before do    
    # add the specified shipping method to the shipment, before it's saved.
    @shipment.update_attribute(:shipping_method, ShippingMethod.find(params[:method_id]))
  end  

  update.response do |wants|
    wants.html do 
      next_step
    end
  end  
  
  update.after do    
    @shipment.update_attribute(:shipping_method, ShippingMethod.find(params[:method_id]))
  end  

  private
  def build_object        
    find_shipment
  end
  
  def object
    return find_shipment if param.blank?
    @object ||= end_of_association_chain.find(param) unless param.nil?
  end

  def find_shipment
    @object = parent_object.shipments.first
    @object ||= Shipment.new(:order => parent_object)
  end
  
  def check_existing
    load_object
    redirect_to edit_order_shipment_url(@order, @shipment) unless @order.shipments.empty? 
  end

  def next_step
    @order.next!
    redirect_to checkout_order_url(@order)
  end
  
  def state_check
    load_object
    if @order.checkout_complete
      redirect_to checkout_order_url(@order) and return 
    end
    # set the state to shipment (in case user has hit back button from some other state)
    @order.update_attribute(:state, "shipment")
  end
end