class CheckoutsController < Spree::BaseController
  include Spree::Checkout::Hooks
  include ActionView::Helpers::NumberHelper # Needed for JS usable rate information

  before_filter :load_data
  before_filter :set_state
  before_filter :enforce_registration, :except => :register
  before_filter :ensure_payment_methods
  helper :users

  resource_controller :singleton
  actions :show, :edit, :update
  belongs_to :order

  ssl_required :update, :edit, :register

  # GET /checkout is invalid but we'll assume a bookmark or user error and just redirect to edit (assuming checkout is still in progress)
  show.wants.html { redirect_to edit_object_url }

  edit.before :edit_hooks
  delivery.edit_hook :load_available_methods
  address.edit_hook :set_ip_address
  payment.edit_hook :load_available_payment_methods
  update.before :clear_payments_if_in_payment_state

  # customized verison of the standard r_c update method (since we need to handle gateway errors, etc)
  def update      
    load_object

    # call the edit hooks for the current step in case we experience validation failure and need to edit again
    edit_hooks
    @checkout.enable_validation_group(@checkout.state.to_sym)
    @prev_state = @checkout.state
    
    before :update

    begin
      if object.update_attributes object_params
        update_hooks
        @order.update_totals!
        after :update
        next_step
        if @checkout.completed_at
          return complete_checkout
        end
      else
        after :update_fails
        set_flash :update_fails
      end
    rescue Spree::GatewayError => ge
      logger.debug("#{ge}:\n#{ge.backtrace.join("\n")}")
      flash.now[:error] = t("unable_to_authorize_credit_card") + ": #{ge.message}"
    end

    render 'edit'
  end

  def register
    load_object
    @user = User.new
    if request.method == :post
      @checkout.email = params[:checkout][:email]
      @checkout.enable_validation_group(:register)
      if @checkout.email.present? and @checkout.save
        redirect_to edit_object_url
      end
      @checkout.errors.add t(:email) unless @checkout.email.present?
    end
  end

  def can_access?
    session[:order_token] ||= params[:order_token]
    parent_object.grant_access?(session[:order_token])
  end

  private

  def object_params
    # For payment step, filter checkout parameters to produce the expected nested attributes for a single payment and its source, discarding attributes for payment methods other than the one selected
    if object.payment?
      if params[:payment_source].present? && source_params = params.delete(:payment_source)[params[:checkout][:payments_attributes].first[:payment_method_id].underscore]
        params[:checkout][:payments_attributes].first[:source_attributes] = source_params
      end
      if (params[:checkout][:payments_attributes])
        params[:checkout][:payments_attributes].first[:amount] = @order.total
      end
    end
    params[:checkout]
  end

  # Calls edit hooks registered for the current step
  def edit_hooks
    edit_hook @checkout.state.to_sym
  end
  # Calls update hooks registered for the current step
  def update_hooks
    update_hook @checkout.state.to_sym
  end

  def complete_checkout
    complete_order
    order_params = {:checkout_complete => true}
    session[:order_id] = nil
    flash[:commerce_tracking] = I18n.t("notice_messages.track_me_in_GA")
    redirect_to order_url(@order, {:checkout_complete => true, :order_token => @order.token})
  end

  def object
    return @object if @object
    @object = parent_object.checkout
    unless params[:checkout] and params[:checkout][:coupon_code]
      # do not create these defaults if we're merely updating coupon code, otherwise we'll have a validation error
      if user = parent_object.user || current_user
        @object.ship_address ||= user.ship_address.clone unless user.ship_address.nil?
        @object.bill_address ||= user.bill_address.clone unless user.bill_address.nil?
      end
      @object.ship_address ||= Address.default
      @object.bill_address ||= Address.default
    end
    @object.email ||= params[:checkout][:email] if params[:checkout]
    @object.email ||= current_user.email if current_user
    @object
  end

  def load_data
    @countries = Checkout.countries.sort
    if object.bill_address && object.bill_address.country
      default_country = object.bill_address.country
    elsif current_user && current_user.bill_address
      default_country = current_user.bill_address.country
    else
      default_country = Country.find Spree::Config[:default_country_id]
    end
    @states = default_country.states.sort

    # prevent editing of a complete checkout
    redirect_to order_url(parent_object) if parent_object.checkout_complete
  end

  def set_state
    object.state = params[:step] || Checkout.state_machine.initial_state(nil).name
    flash[:analytics] = "/checkout/#{object.state}"
  end

  def next_step
    @checkout.next!
    # call edit hooks for this next step since we're going to just render it (instead of issuing a redirect)
    edit_hooks
  end

  def load_available_methods
    @available_methods = rate_hash
    @checkout.shipping_method_id ||= @available_methods.first[:id] unless @available_methods.empty?
  end

  def clear_payments_if_in_payment_state
    if @checkout.payment?
      @checkout.payments.clear
    end
  end
  
  def load_available_payment_methods 
    @payment_methods = PaymentMethod.available   
    if @checkout.payment and @checkout.payment.payment_method
      @payment_method = @checkout.payment.payment_method
    else
      @payment_method = @payment_methods.first
    end
  end

  def set_ip_address
    @checkout.update_attribute(:ip_address, request.env['REMOTE_ADDR'])
  end

  def complete_order
    if @checkout.order.out_of_stock_items.empty?
      flash[:notice] = t('order_processed_successfully')
    else
      flash[:notice] = t('order_processed_but_following_items_are_out_of_stock')
      flash[:notice] += '<ul>'
      @checkout.order.out_of_stock_items.each do |item|
        flash[:notice] += '<li>' + t(:count_of_reduced_by,
                              :name => item[:line_item].variant.name,
                              :count => item[:count]) +
                          '</li>'
      end
      flash[:notice] += '<ul>'
    end
  end

  def rate_hash
    begin
      @checkout.shipping_methods.collect do |ship_method|
        @checkout.shipment.shipping_method = ship_method
        { :id => ship_method.id,
          :name => ship_method.name,
          :rate => number_to_currency(ship_method.calculate_cost(@checkout.shipment)) }
      end
    rescue Spree::ShippingError => ship_error
      flash[:error] = ship_error.to_s
      []
    end
  end

  def enforce_registration
    return if current_user or Spree::Config[:allow_anonymous_checkout]
    return if Spree::Config[:allow_guest_checkout] and object.email.present?
    store_location
    redirect_to register_order_checkout_url(parent_object)
  end

  def accurate_title
    I18n.t(:checkout)
  end
  
  def ensure_payment_methods
    if PaymentMethod.available.none?
      flash[:error] = t(:no_payment_methods_available)
      redirect_to edit_order_path(params[:order_id])
      false
    end
  end
  
end
