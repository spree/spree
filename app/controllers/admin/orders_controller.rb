class Admin::OrdersController < Admin::BaseController
  require 'spree/gateway_error'
  resource_controller
  before_filter :initialize_txn_partials
  before_filter :initialize_order_events
  before_filter :load_object, :only => [:fire, :resend]

  in_place_edit_for :address, :firstname
  in_place_edit_for :address, :lastname
  in_place_edit_for :address, :address1
  in_place_edit_for :address, :address2
  in_place_edit_for :address, :city
  in_place_edit_for :address, :zipcode
  in_place_edit_for :address, :phone
  in_place_edit_for :user, :email
  
  def fire   
    # TODO - possible security check here but right now any admin can before any transition (and the state machine 
    # itself will make sure transitions are not applied in the wrong state)
    event = params[:e]
    Order.transaction do 
      @order.send("#{event}!")
      @order.state_events.create(:name => t(event), :user => current_user)
    end
    flash[:notice] = t('Order Updated')
  rescue Spree::GatewayError => ge
    flash[:error] = "#{ge.message}"
  ensure
    redirect_to :back
  end
  
  def resend
    OrderMailer.deliver_confirm(@order, true)
    flash[:notice] = t('Order Email Resent')
    redirect_to :back
  end
  
  private
  def collection   
    default_stop = (Date.today + 1).to_s(:db)
    @filter = params.has_key?(:filter) ? OrderFilter.new(params[:filter]) : OrderFilter.new

    scope = Order.scoped({:include => [:shipments, :payments, :address]})
    scope = scope.by_number @filter.number unless @filter.number.blank?
    scope = scope.by_customer @filter.customer unless @filter.customer.blank?
    scope = scope.between(@filter.start, (@filter.stop.blank? ? default_stop : @filter.stop)) unless @filter.start.blank?
    scope = scope.by_state @filter.state.classify.downcase.gsub(" ", "_") unless @filter.state.blank?
    scope = scope.conditions "lower(addresses.firstname) LIKE ?", "%#{@filter.firstname.downcase}%" unless @filter.firstname.blank?
    scope = scope.conditions "lower(addresses.lastname) LIKE ?", "%#{@filter.lastname.downcase}%" unless @filter.lastname.blank?
    scope = scope.checkout_completed(@filter.checkout == '1' ? false : true)

    @collection = scope.find(:all, :order => 'orders.created_at DESC', :include => :user, :page => {:size => 15, :current =>params[:p], :first => 1})
  end
  
  # Allows extensions to add new forms of payment to provide their own display of transactions
  def initialize_txn_partials
    @txn_partials = []
  end
  
  # Used for extensions which need to provide their own custom event links on the order details view.
  def initialize_order_events
    @order_events = ["cancel"]
  end
  

end
