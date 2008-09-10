class AddressesController < Admin::BaseController
  before_filter :check_existing, :only => :new
  before_filter :load_data
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
  
  private
  def load_data
    @states = State.find(:all, :order => 'name')
    @countries = Country.find(:all)
  end
  
  def next_step
    @order.next!
    redirect_to checkout_order_url(@order)
  end
  
  def check_existing
    redirect_to edit_order_address_url if parent_object.address 
  end
  
end