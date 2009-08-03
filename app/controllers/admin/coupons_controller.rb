class Admin::CouponsController < Admin::BaseController
  resource_controller         
  before_filter :load_data

  update.response do |wants|
    wants.html { redirect_to collection_url }
  end  
  
  create.response do |wants|
    wants.html { redirect_to edit_object_url }
  end

  private       
  def build_object
    @object ||= end_of_association_chain.send parent? ? :build : :new, object_params 
    @object.calculator = params[:coupon][:calculator_type].constantize.new if params[:coupon]
  end
  
  def load_data     
    # TODO - remove hard coded
    @coupon_calculators = [FlatRateCouponCalculator, FlatPercentCouponCalculator]
  end  
end