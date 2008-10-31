class AddressesController < Admin::BaseController
  before_filter :check_existing, :only => :new
  before_filter :load_data
  before_filter :load_countries, :except => :country_changed
  layout 'application'
  resource_controller :singleton
  
  belongs_to :order, :polymorphic => true
  
  create.before do 
    # TODO - do not reset the state if the checkout is complete
    # TODO - consider make this state check DRY for use in other controller
    # set the state to address (in case user has hit back button from some other state)
    @order.state = "address"
  end

  create.response do |wants|
    wants.html do 
      next_step
    end
  end
  
  update.response do |wants|
    wants.html do 
      next_step
    end
  end
  
  def country_changed
    render :partial => "states"
  end
  
  private
  def load_data
    load_object
 
    @selected_country_id = params[:address][:country_id].to_i if params.has_key?('address')
    @selected_country_id ||= @order.address.country_id unless @order.nil? || @order.address.nil?  
    @selected_country_id ||= Spree::Config[:default_country_id]

    @states = State.find_all_by_country_id(@selected_country_id, :order => 'name')  
  end
  
  def load_countries
    @countries = Country.all
  end
  
  def next_step
    @order.next!
    redirect_to checkout_order_url(@order)
  end
  
  def check_existing
    redirect_to edit_order_address_url if parent_object.address 
  end
  
end