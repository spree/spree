class Admin::CreditcardPaymentsController < Admin::BaseController
  before_filter :load_data
  before_filter :load_amount, :except => :country_changed
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
  
  # override r_c default with special presenter logic
  def edit 
    @payment_presenter = PaymentPresenter.new(:creditcard => object.creditcard, :address => object.creditcard.address)    
  end
  
  # override r_c default with special presenter logic
  def update
    load_payment_presenter
    creditcard = @creditcard_payment.creditcard
    creditcard.address = @payment_presenter.address
    creditcard.save
    flash[:notice] = t("Updated Successfully")
    redirect_to edit_object_url 
  end

  def cvv
    render :layout => false
  end
  
  def country_changed
    render :partial => "shared/states", :locals => {:presenter_type => "payment"}
  end
         
  def capture       
    if @creditcard_payment.can_capture?      
      creditcard = @creditcard_payment.creditcard
      authorization = @creditcard_payment.find_authorization
      Creditcard.transaction do 
        creditcard.order.state_events.create(:name => t('pay'), :user => current_user, :previous_state => creditcard.order.state)
        creditcard.capture(authorization)
        @creditcard_payment.amount = authorization.amount
        @creditcard_payment.save
      end
      flash[:notice] = t("credit_card_capture_complete")
    else  
      flash[:error] = t("unable_to_capture_credit_card")    
    end 
    redirect_to edit_object_url
  end  
  
  private
  def load_data 
    load_object
    @selected_country_id = params[:payment_presenter][:address_country_id].to_i if params.has_key?('payment_presenter')
    @selected_country_id ||= @order.creditcards.last.address.country_id unless @order.creditcards.empty?
    @selected_country_id ||= Spree::Config[:default_country_id]
 
    @states = State.find_all_by_country_id(@selected_country_id, :order => 'name')  
    @countries = Country.find(:all)

    month = (params[:payment_presenter] && params[:payment_presenter][:creditcard_month]) ? params[:payment_presenter][:creditcard_month].to_i : Date.today.month
    year = (params[:payment_presenter] && params[:payment_presenter][:creditcard_year]) ? params[:payment_presenter][:creditcard_year].to_i : Date.today.year
    @date = Date.new(year, month, 1)
  end

  def load_amount
    @amount = params[:amount] || @order.total
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
