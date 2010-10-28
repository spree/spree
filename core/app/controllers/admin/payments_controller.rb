class Admin::PaymentsController < Admin::BaseController
  before_filter :load_data
  before_filter :load_amount, :except => :country_changed
  resource_controller
  belongs_to :order

  def create
    build_object
    load_object

    begin
      unless @payment.save
        response_for :create_fails
        return
      end

      if @order.completed?
        @payment.process!
        set_flash :create
        redirect_to collection_path
      else
        #This is the first payment (admin created order)
        until @order.completed?
          @order.next!
        end
        flash.notice = t('new_order_completed')
        redirect_to admin_order_url(@order)
      end

    rescue Spree::GatewayError => e
      flash[:error] = "#{e.message}"
      redirect_to new_object_path
    end
  end

  def fire
    # TODO: consider finer-grained control for this type of action (right now anyone in admin role can perform)
    load_object
    return unless event = params[:e] and @payment.payment_source
    if @payment.payment_source.send("#{event}", @payment)
      flash.notice = t('payment_updated')
    else
      flash[:error] = t('cannot_perform_operation')
    end
  rescue Spree::GatewayError => ge
    flash[:error] = "#{ge.message}"
  ensure
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
    @payment_methods = PaymentMethod.available(:back_end)
    if object and object.payment_method
      @payment_method = object.payment_method
    else
      @payment_method = @payment_methods.first
    end
    @previous_cards = @order.creditcards.with_payment_profile
  end

  def load_amount
    @amount = params[:amount] || @order.total
  end

  def build_object
    @object = model.new(object_params)
    @object.order = parent_object
    if @object.payment_method.is_a?(Gateway) and @object.payment_method.payment_profiles_supported? and params[:card].present? and params[:card] != 'new'
      @object.source = Creditcard.find_by_id(params[:card])
    end
    @object
  end

end
