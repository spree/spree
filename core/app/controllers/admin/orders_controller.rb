class Admin::OrdersController < Admin::BaseController
  require 'spree/gateway_error'
  resource_controller
  before_filter :initialize_txn_partials
  before_filter :initialize_order_events
  before_filter :load_object, :only => [:fire, :resend, :history]
  before_filter :ensure_line_items, :only => [:update]

  update do
    flash nil
    wants.html do
      if @order.bill_address.nil? || @order.ship_address.nil?
        redirect_to edit_admin_order_checkout_url(@order)
      else
        redirect_to admin_order_url(@order)
      end
    end
  end

  def new
    @order = Order.create
  end

  def fire
    # TODO - possible security check here but right now any admin can before any transition (and the state machine
    # itself will make sure transitions are not applied in the wrong state)
    event = params[:e]
    Order.transaction do
      @order.send("#{event}!")
    end
    flash.notice = t('order_updated')
  rescue Spree::GatewayError => ge
    flash[:error] = "#{ge.message}"
  ensure
    redirect_to :back
  end

  def resend
    OrderMailer.deliver_confirm(@order, true)
    flash.notice = t('order_email_resent')
    redirect_to :back
  end

  private

  def object
    @object ||= Order.find_by_number(params[:id], :include => :adjustments) if params[:id]
    return @object || find_order
  end

  def collection
    params[:search] ||= {}
    if !params[:search][:created_at_greater_than].blank?
      params[:search][:created_at_greater_than] = Time.zone.parse(params[:search][:created_at_greater_than]).beginning_of_day rescue ""
    end

    if !params[:search][:created_at_less_than].blank?
      params[:search][:created_at_less_than] = Time.zone.parse(params[:search][:created_at_less_than]).end_of_day rescue ""
    end

    if params[:search].delete(:completed_at_not_null) == "1"
      params[:search][:completed_at_not_null] = true
    end
    
    params[:search][:order] ||= "descend_by_created_at"
    @search = Order.searchlogic(params[:search])

    # QUERY - get per_page from form ever???  maybe push into model
    # @search.per_page ||= Spree::Config[:orders_per_page]

    @collection = @search.do_search.paginate(:include  => [:user, :shipments, :payments],
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

  def ensure_line_items
    load_object
    if @order.line_items.empty?
      @order.errors.add(:line_items, t('errors.messages.blank'))
      @order.update_totals
      render :edit
    end
  end

end
