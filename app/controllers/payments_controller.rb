class PaymentsController < Admin::BaseController
  before_filter :check_existing, :only => :new
  before_filter :load_data
  layout 'application'
  resource_controller :singleton

  belongs_to :order

  update.response do |wants|
    wants.html do 
      @order.next!
      redirect_to checkout_order_url(@order)
    end
  end

  private
  def load_data
    #@states = State.find(:all, :order => 'name')
    #@countries = Country.find(:all)
  end

  def check_existing
    # TODO - redirect to the next step if there is no outstanding balance
  end

end
