class Admin::PaymentsController < Admin::BaseController
  before_filter :load_data
  before_filter :load_amount, :except => :country_changed
  resource_controller
  belongs_to :order
  ssl_required

  def create
    build_object
    load_object

    unless object.save
      response_for :create_fails
      return
    end

    begin 

      if @order.checkout.state == "complete"
        object.process!
        set_flash :create
        redirect_to collection_path
      else
        #This is the first payment (admin created order)
        until @order.checkout.state == "complete"
          @order.checkout.next!
        end
        flash[:notice] = t('new_order_completed')
        redirect_to admin_order_url(@order)
      end

    rescue Spree::GatewayError => e
      flash.now[:error] = "#{e.message}"
      response_for :create_fails
    end
  end

  def fire
    # TODO - possible security check here
    load_object
    return unless event = params[:e] and @payment.source
    Payment.transaction do
      @payment.source.send("#{event}", @payment)
    end
    flash[:notice] = t('payment_updated')
  rescue Spree::GatewayError => ge
    flash[:error] = "#{ge.message}"
  ensure
    redirect_to collection_path
  end  

  def finalize
    object.finalize!
    redirect_to collection_path
  end
  
  private

  def object    
    @object ||= Payment.find(param) unless param.nil?
    @object
  end

  def object_params
    if params[:payment] and params[:payment_source] and source_params = params.delete(:payment_source)[params[:payment][:payment_method_id]]
      params[:payment][:source_attributes] = source_params
    end
    params[:payment]
  end

  def load_data
    load_object
    @payment_methods = PaymentMethod.available   
    if object and object.payment_method
      @payment_method = object.payment_method
    else
      @payment_method = @payment_methods.first
    end
    @previous_cards = @order.creditcards.with_payment_profile
    @countries = Country.find(:all).sort
    @shipping_countries = Checkout.countries.sort
    if current_user && current_user.bill_address
      default_country = current_user.bill_address.country
    else
      default_country = Country.find Spree::Config[:default_country_id]
    end
    @states = default_country.states.sort
  end

  def load_amount
    @amount = params[:amount] || @order.total
  end

  def build_object
    @object = model.new(object_params)
    @object.payable = parent_object.checkout
    @payment = @object
    if @object.payment_method.is_a?(Gateway) and @object.payment_method.payment_profiles_supported? and params[:card].present? and params[:card] != 'new'
      @object.source = Creditcard.find_by_id(params[:card])
    end
    @object
  end

end
