class CreditcardsController < Spree::BaseController
  before_filter :load_data
  before_filter :validate_payment, :only => :create   
  before_filter :state_check, :except => [:country_changed, :cvv]  
  ssl_required :new, :create
  layout 'application'
  resource_controller
  
  belongs_to :order
  actions :new, :create

  # override the r_c create since we need special logic to deal with the presenter in the create case
  def create
    creditcard = @payment_presenter.creditcard
    creditcard.address = @payment_presenter.address
    creditcard.order = @order
    
    begin
      creditcard.authorize(@order.total)
    rescue Spree::GatewayError => ge
      flash.now[:error] = "Authorization Error: #{ge.message}"
      render :action => "new" and return 
    end
    creditcard.save
    @order.next!
    redirect_to checkout_order_url(@order)
  end

  def cvv
    render :layout => false
  end
  
  def country_changed
    render :partial => "shared/states", :locals => {:presenter_type => "creditcard"}
  end
  
  private
  def load_data 
    load_object
    @selected_country_id = params[:payment_presenter][:address_country_id].to_i if params.has_key?('payment_presenter')
    @selected_country_id ||= @order.ship_address.country_id unless @order.nil? || @order.ship_address.nil?  
    @selected_country_id ||= Spree::Config[:default_country_id]
 
    @states = State.find_all_by_country_id(@selected_country_id, :order => 'name')  
    @countries = Country.find(:all)

    month = (params[:payment_presenter] && params[:payment_presenter][:creditcard_month]) ? params[:payment_presenter][:creditcard_month].to_i : Date.today.month
    year = (params[:payment_presenter] && params[:payment_presenter][:creditcard_year]) ? params[:payment_presenter][:creditcard_year].to_i : Date.today.year
    @date = Date.new(year, month, 1)
  end
  
  def build_object
    address = parent_object.ship_address ? parent_object.ship_address : Address.new(:country_id => @selected_country_id)
    @payment_presenter ||= PaymentPresenter.new(:address => address)    
  end
  
  def validate_payment
    # load the object so that its available to the form in the event of a validation error
    load_object
    load_payment_presenter
    render :action => "new" unless @payment_presenter.valid?
  end
  
  def load_payment_presenter
    payment_presenter = PaymentPresenter.new(params[:payment_presenter]) 
    payment_presenter.creditcard.first_name = payment_presenter.address.firstname
    payment_presenter.creditcard.last_name = payment_presenter.address.lastname
    @payment_presenter = payment_presenter
  end
  
  def state_check
    if @order.checkout_complete
      # if order has already completed user shouldn't be able to enter new cc information
      redirect_to checkout_order_url(@order) and return 
    end
  end  
end
