class Admin::PaymentsController < Admin::BaseController
  before_filter :load_data
  before_filter :load_amount, :except => :country_changed
  resource_controller
  belongs_to :order
  ssl_required

  update.wants.html { redirect_to edit_object_url }

  def create
    build_object
    load_object

    if object.class == CreditcardPayment
      
      unless object.valid?
        response_for :create_fails
        return
      end
      # object doesn't get saved here, that happens in @creditcard.authorize/capture
      begin 
        if @order.checkout.state == "complete"
          #This is a second or subsequent payment
          @creditcard_payment.creditcard.checkout = @order.checkout
          if Spree::Config[:auto_capture]
            @creditcard_payment.creditcard.purchase(@creditcard_payment.amount)
          else
            @creditcard_payment.creditcard.authorize(@creditcard_payment.amount)
          end
        else
          #This is the first payment
          @order.checkout.creditcard = @creditcard_payment.creditcard
          until @order.checkout.state == "complete"
            @order.checkout.next!
          end
        end
        redirect_to collection_path
      rescue Spree::GatewayError => e
        flash.now[:error] = "#{e.message}"
        response_for :create_fails
      end

    else

      if object.save
        set_flash :create
        redirect_to collection_path
      else
        set_flash :create_fails
        response_for :create_fails
      end

    end
  end



  private
  def load_data
    load_object
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
    @object.order = parent_object
    @payment = @object

    if @object.class == CreditcardPayment
      if current_gateway.payment_profiles_supported? and !params[:card].blank? and params[:card] != 'new'
        @object.creditcard = Creditcard.find_by_id(params[:card])
      else
        @object.creditcard ||= Creditcard.new(:checkout => @object.order.checkout)
      end
    end
    @object
  end

  def end_of_association_chain
    parent_object.payments  
  end
  
  # Set class for STI based on selected payment type
  def model_name
    return 'payment' if params[:action] == 'index'
    if %w(cheque_payment creditcard_payment).include?(params[:payment_type])
      params[:payment_type]
    elsif params[:action] == 'new'
      'creditcard_payment'
    else
      'payment'
    end
  end
  def object_name
    model_name
  end

end
