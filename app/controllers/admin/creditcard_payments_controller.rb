class Admin::CreditcardPaymentsController < Admin::BaseController
  before_filter :load_data
  before_filter :load_amount, :except => :country_changed
  before_filter :complete_checkout, :only => :create
  resource_controller
  belongs_to :order
  ssl_required

  update.wants.html { redirect_to edit_object_url }

  def capture
    if @creditcard_payment.can_capture?
      #Creditcard.transaction do
      #  @order.state_events.create(:name => t('pay'), :user => current_user, :previous_state => order.state)
        @creditcard_payment.capture#(authorization)
      #end
      flash[:notice] = t("credit_card_capture_complete")
    else
      flash[:error] = t("unable_to_capture_credit_card")
    end
    redirect_to edit_object_url
  end

  private
  def load_data
    load_object
    @countries = Country.find(:all).sort
    @shipping_countries = parent_object.shipping_countries.sort
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
    @object ||= end_of_association_chain.send parent? ? :build : :new, object_params
    @object.creditcard = Creditcard.new(:checkout => @object.order.checkout) unless @object.creditcard
    @object
  end

  def complete_checkout
    build_object
    load_object

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
        @order.checkout.next
      end
    end

    redirect_to admin_order_payments_url(@order)
  end

end
