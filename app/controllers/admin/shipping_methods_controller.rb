class Admin::ShippingMethodsController < Admin::BaseController    
  resource_controller
  before_filter :load_data
  
  update.response do |wants|
    wants.html { redirect_to collection_url }
  end  
  
  create.response do |wants|
    wants.html { redirect_to collection_url }
  end
  
  private       
  def build_object
    @object ||= end_of_association_chain.send parent? ? :build : :new, object_params 
    @object.calculator = params[:shipping_method][:calculator_type].constantize.new if params[:shipping_method]
  end
  
  def load_data     
    @available_zones = Zone.find :all, :order => :name                      
    # TODO - remove hard coded
    @shipping_calculators = [FlatRateShippingCalculator]
  end    
end
