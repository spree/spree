class Admin::OrdersController < Admin::BaseController
  require 'spree/gateway_error'
  resource_controller
  before_filter :initialize_txn_partials
  before_filter :initialize_order_events
  before_filter :load_object, :only => [:fire, :resend]

  in_place_edit_for :user, :email

  def fire   
    # TODO - possible security check here but right now any admin can before any transition (and the state machine 
    # itself will make sure transitions are not applied in the wrong state)
    event = params[:e]
    Order.transaction do 
      @order.state_events.create(:name => t(event), :user => current_user, :previous_state => @order.state)
      @order.send("#{event}!")
    end
    flash[:notice] = t('order_updated')
  rescue Spree::GatewayError => ge
    flash[:error] = "#{ge.message}"
  ensure
    redirect_to :back
  end
  
  def resend
    OrderMailer.deliver_confirm(@order, true)
    flash[:notice] = t('order_email_resent')
    redirect_to :back
  end
  
  private

  def collection
    @search = Order.search(params[:search])
    @search.order ||= "descend_by_created_at"

    # QUERY - get per_page from form ever???  maybe push into model
    # @search.per_page ||= Spree::Config[:orders_per_page]

    # turn on show-complete filter by default
    unless params[:search] && params[:search][:checkout_completed_at_not_null]
      @search.checkout_completed_at_not_null = true 
    end
    
    @collection = @search.paginate(:include  => [:user, :shipments, {:creditcard_payments => {:creditcard => :address}}],
                                   :per_page => Spree::Config[:orders_per_page], 
                                   :page     => params[:page])
  end

  # Allows extensions to add new forms of payment to provide their own display of transactions
  def initialize_txn_partials
    @txn_partials = []
  end
  
  # Used for extensions which need to provide their own custom event links on the order details view.
  def initialize_order_events
    @order_events = %w{cancel resume}
  end
  

end
