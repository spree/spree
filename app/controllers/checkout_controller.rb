class CheckoutController < Spree::BaseController    
  before_filter :load_data
  before_filter :build_object, :except => [:new, :create]
  resource_controller
  model_name :checkout_presenter
  object_name :checkout_presenter
  
  def cvv
    render :layout => false
  end  
         
  def select_country         
    @states = @object.bill_address.country.states#, :order => 'name')  
    respond_to do |format|
      format.js
    end
  end
  
  private
  def build_object
    @order = Order.find_by_number(params[:order_number])
    @object ||= end_of_association_chain.send parent? ? :build : :new, params[:checkout_presenter]
  end
  
  def load_data
    @countries = Country.find(:all)    
    @states = []
  end
end