class Admin::OrdersController < Admin::BaseController
  require 'spree/gateway_error'
  resource_controller
  before_filter :initialize_txn_partials
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
    @filter = params.has_key?(:filter) ? OrderFilter.new(params[:filter]) : OrderFilter.new(:checkout => "1")
 
    scopes = []
    if params[:filter] and @filter.valid?
      default_stop = (Date.today + 1).to_s(:db)
     
      scopes << [ :by_number, @filter.number ] unless @filter.number.blank?
      scopes << [ :by_customer, @filter.customer ] unless @filter.customer.blank?
      scopes << [ :between, @filter.start, (@filter.stop.blank? ? default_stop : @filter.stop) ] unless @filter.start.blank?
      scopes << [ :by_state, @filter.state.classify.downcase.gsub(" ", "_") ] unless @filter.state.blank?
      scopes << [ :checkout_completed, @filter.checkout=='1' ? true : false] unless @filter.checkout.blank?  
    else
      scopes << [ :checkout_completed, true]  
    end
    
    
    @collection = (scopes.inject(Order) {|m,v| m.scopes[v.shift].call(m, *v) }).find(:all, :order => 'orders.created_at DESC', :include => :user,
       :page => {:size => 15, :current =>params[:p], :first => 1})

  end
  
  # Allows extensions to add new forms of payment to provide their own display of transactions
  def initialize_txn_partials
    @txn_partials = []
  end

end
