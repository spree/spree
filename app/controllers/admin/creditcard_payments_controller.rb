class Admin::CreditcardPaymentsController < Admin::BaseController
  before_filter :load_data
  before_filter :load_amount, :except => :country_changed
  resource_controller
  belongs_to :order
  ssl_required

  update do
    wants.html { redirect_to edit_object_url }
  end

  def country_changed
  end
         
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
    @selected_country_id = params[:payment_presenter][:address_country_id].to_i if params.has_key?('payment_presenter')
    @selected_country_id ||= @order.bill_address.country_id if @order and @order.bill_address
    @selected_country_id ||= Spree::Config[:default_country_id]
 
    @states = State.find_all_by_country_id(@selected_country_id, :order => 'name')  
    @countries = Country.find(:all)
  end

  def load_amount
    @amount = params[:amount] || @order.total
  end
           
  def build_object
    @object ||= end_of_association_chain.send parent? ? :build : :new, object_params
    @object.creditcard = Creditcard.new(:address => @object.order.bill_address.clone) unless @object.creditcard
    @object
  end
  
end
