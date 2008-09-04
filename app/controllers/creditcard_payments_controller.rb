class CreditcardPaymentsController < Admin::BaseController
  before_filter :load_data
  before_filter :check_existing, :only => :new
  before_filter :validate_payment, :only => :create
  layout 'application'
  resource_controller :singleton
  
  belongs_to :order

  # override the r_c create since we need special logic to deal with the presenter in the create case
  def create
    creditcard_payment = CreditcardPayment.new(:order => @order, :address => @payment_presenter.address)            
    creditcard_payment.creditcard = @payment_presenter.creditcard
    begin
      creditcard_payment.save
    rescue SecurityError => se
      flash.now[:error] = "Authorization Error: #{se.message}"
      render :action => "new" and return 
    end
    @order.next!
    redirect_to checkout_order_url(@order)
  end

  def cvv
    render :layout => false
  end
  
  private
  def load_data
    @states = State.find(:all, :order => 'name')
    @countries = Country.find(:all)
  end

  def check_existing
    # TODO - redirect to the next step if there is no outstanding balance
  end

  def build_object
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