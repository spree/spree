class CreditcardsController < Spree::BaseController
  before_filter :load_data
  before_filter :validate_payment, :only => :create
  ssl_required :new, :create
  layout 'application'
  resource_controller
  
  belongs_to :order

  new_action.before do 
    #set default country for form_address
    @payment_presenter = PaymentPresenter.new(:address => Address.new(:country_id => @selected_country_id))
  end

  # override the r_c create since we need special logic to deal with the presenter in the create case
  def create
    creditcard = @payment_presenter.creditcard
    creditcard.address = @payment_presenter.address
    creditcard.order = @order
    
    begin
      creditcard.authorize(@order.total)
      #creditcard.authorize(@order) if creditcard.respond_to?(:authorize)
      #creditcard_payment.creditcard = creditcard
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
  end
  
  def build_object
    address = parent_object.ship_address ? parent_object.ship_address : Address.new
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
end