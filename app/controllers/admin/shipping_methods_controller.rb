class Admin::ShippingMethodsController < Admin::BaseController    
  resource_controller
  before_filter :load_data
  
  update.wants.html { redirect_to edit_object_url }
  create.wants.html { redirect_to edit_object_url }
  
  private       
  def build_object
    @object ||= end_of_association_chain.send((parent? ? :build : :new), object_params)
    @object.calculator = params[:shipping_method][:calculator_type].constantize.new if params[:shipping_method]
    @object
  end
  
  def load_data
    @available_zones = Zone.find :all, :order => :name                      
    @calculators = ShippingMethod.calculators
  end    
end
