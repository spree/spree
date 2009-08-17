class Admin::ShippingRatesController < Admin::BaseController
  resource_controller
  before_filter :load_data

  update.wants.html { redirect_to edit_object_url }
  create.wants.html { redirect_to edit_object_url }
    
  private 
  def build_object
    @object ||= end_of_association_chain.send((parent? ? :build : :new), object_params)
    @object.calculator = params[:tax_rate][:calculator_type].constantize.new if params[:tax_rate]
    @object.calculator ||= ShippingRate.calculators.first.new
    @object
  end  
  def load_data
    @shipping_methods = ShippingMethod.find(:all, :order => :name)
    @shipping_categories = ShippingCategory.find(:all, :order => :name)
    @calculators = ShippingRate.calculators
  end
end
