class Admin::CheckoutController  < Admin::BaseController

  helper :checkout
  before_filter :load_order

  def update
    begin
      if @order.update_attributes(object_params)
        if @order.next
          state_callback(:after)
          if @order.completed?
            flash[:notice] = I18n.t(:order_processed_successfully)
            redirect_to admin_order_path(@order.number) and return
          else
            redirect_to admin_orders_checkout_path(@order.number, @order.state) and return
          end
        end
      end
    rescue Spree::GatewayError
      flash[:error] = I18n.t(:payment_processing_failed)
      redirect_to admin_orders_checkout_path(@order.number, 'payment')
      return
    end
    render :edit
  end
  
  def edit
    @order.state = params[:state] || @order.state
    unless @order.changed.empty?
      unless @order.save
        redirect_to admin_checkout_state_path(@order.number, @order.state) and return
      end
    end
  end
  
  private
  
  def object_params
    # For payment step, filter order parameters to produce the expected nested attributes for a single payment and its source, discarding attributes for payment methods other than the one selected
    if @order.payment?
      if params[:payment_source].present? && source_params = params.delete(:payment_source)[params[:order][:payments_attributes].first[:payment_method_id].underscore]
        params[:order][:payments_attributes].first[:source_attributes] = source_params
      end
      if (params[:order][:payments_attributes])
        params[:order][:payments_attributes].first[:amount] = @order.total
      end
    end
    params[:order]
  end
  
  def load_order
    @order = Order.find_by_number(params[:order_number])
    #order.state = params[:state] if params[:state]
    state_callback(:before)
  end
  
  def before_address
    @order.bill_address ||= Address.new(:country => default_country)
    @order.ship_address ||= Address.new(:country => default_country)
  end
  
  def before_delivery
    @order.shipping_method ||= (@order.rate_hash.first && @order.rate_hash.first[:shipping_method])
  end

  def before_payment
    @order.payments.destroy_all if request.put?
  end

  def after_complete
    session[:order_id] = nil
  end
  
  def default_country
    Country.find Spree::Config[:default_country_id]
  end
  
  def state_callback(before_or_after = :before)
    method_name = :"#{before_or_after}_#{@order.state}"
    send(method_name) if respond_to?(method_name, true)
  end

end
