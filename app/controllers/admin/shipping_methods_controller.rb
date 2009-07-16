

class Admin::ShippingMethodsController < Admin::BaseController    
  resource_controller
  before_filter :load_data
  layout 'admin'
       
  update.before do
    calc_type = params[:shipping_method][:calculator_type].constantize
    next if calc_type == @shipping_method.calculator.class
    @shipping_method.calculator = calc_type.new
    @shipping_method.save
  end
  
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
