class Admin::ShippingRatesController < Admin::BaseController
  resource_controller
  before_filter :load_data
  
  private 
  
  def load_data
    @available_shipping_methods = ShippingMethod.find(:all, :order => :name)
    @available_categories = ShippingCategory.find(:all, :order => :name)
    @calculators = Calculator.all_available_for(@object)
  end
end
