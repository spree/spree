class Admin::CreditcardPaymentsController < Admin::BaseController
  before_filter :load_data
  before_filter :validate_payment, :only => :create
  resource_controller
  belongs_to :order
  ssl_required

  # override the r_c defauult since he have the special presenter logic and we need to capture before storing cc info.
  def create
    creditcard = @payment_presenter.creditcard
    creditcard.address = @payment_presenter.address
    creditcard.order = @order
    begin
      creditcard.purchase(params[:amount])
    rescue Spree::GatewayError => ge
      flash.now[:error] = "Authorization Error: #{ge.message}"
      render :action => "new" and return 
    end
    @order.creditcards << creditcard
    # TODO - eventually the amount should be passed as a parameter
    @order.save
    redirect_to admin_order_payments_url(@order)
  end

  def cvv
    render :layout => false
  end
  
  def country_changed
    render :partial => "states"
  end
    
  private
  def load_data 
    load_object
    @selected_country_id = params[:payment_presenter][:address_country_id].to_i if params.has_key?('payment_presenter')
    @selected_country_id ||= @order.address.country_id unless @order.nil? || @order.address.nil?  
 
    @states = State.find_all_by_country_id(@selected_country_id, :order => 'name')  
    @countries = Country.find(:all)
    @amount = params[:amount] || @order.total
  end
  
  def build_object
    # TODO - build with parent billing address as default
    @payment_presenter ||= PaymentPresenter.new(:address => parent_object.address)
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
