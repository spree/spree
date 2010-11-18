class Admin::TaxRatesController < Admin::BaseController
  resource_controller
  before_filter :load_data
                                                          
  create.success.wants.html { redirect_to collection_url }
  update.success.wants.html { redirect_to collection_url }   
  destroy.success.wants.js { render_js_for_destroy }
  
  update.after :update_after
  create.after :create_after
    
  private 
  def build_object
    @object ||= end_of_association_chain.send((parent? ? :build : :new), object_params)
    @object.calculator = params[:tax_rate][:calculator_type].constantize.new if params[:tax_rate]
    @object.calculator ||= Calculator::SalesTax.new
    @object
  end  
  def load_data
    @available_zones = Zone.order(:name)
    @available_categories = TaxCategory.order(:name)
    @calculators = TaxRate.calculators
  end
  
  def update_after
    Rails.cache.delete('vat_rates')
  end
  
  def create_after
    Rails.cache.delete('vat_rates')
  end
end
