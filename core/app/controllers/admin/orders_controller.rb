class Admin::OrdersController < Admin::BaseController
  require 'spree/gateway_error'
  resource_controller
  before_filter :initialize_txn_partials
  before_filter :initialize_order_events
  before_filter :load_object, :only => [:fire, :resend, :history, :user]
  before_filter :ensure_line_items, :only => [:update]

  update do
    flash nil
    wants.html do
      if !@order.line_items.empty?
        unless @order.complete?

          if params[:order].key?(:email)
            @order.shipping_method = @order.available_shipping_methods(:front_end).first
            @order.create_shipment!
            redirect_to edit_admin_order_shipment_path(@order, @order.shipment)
          else
            redirect_to user_admin_order_path(@order)
          end

        else
          redirect_to admin_order_path(@order)
        end
      else
        render :action => :new
      end
    end
  end

  def new
    @order = @object = Order.create
  end

  def fire
    # TODO - possible security check here but right now any admin can before any transition (and the state machine
    # itself will make sure transitions are not applied in the wrong state)
    event = params[:e]
    if @order.send("#{event}")
      flash.notice = t('order_updated')
    else
      flash[:error] = t('cannot_perform_operation')
    end
  rescue Spree::GatewayError => ge
    flash[:error] = "#{ge.message}"
  ensure
    redirect_to :back
  end

  def resend
    OrderMailer.confirm_email(@order, true).deliver
    flash.notice = t('order_email_resent')
    redirect_to :back
  end

  def user
    @order.build_bill_address(:country_id => Spree::Config[:default_country_id]) if @order.bill_address.nil?
    @order.build_ship_address(:country_id => Spree::Config[:default_country_id]) if @order.ship_address.nil?
  end

  private

  def object
    @object ||= Order.find_by_number(params[:id], :include => :adjustments) if params[:id]
    return @object || current_order
  end

  def collection
    params[:search] ||= {}

    if params[:search].present?
      if params[:search].delete(:completed_at_not_null) == "1"
        params[:search][:completed_at_not_null] = "1"
      end
    else
      params[:search][:completed_at_not_null] = "1"
    end

    if !params[:search][:completed_at_greater_than].blank?
      params[:search][:completed_at_greater_than] = Time.zone.parse(params[:search][:completed_at_greater_than]).beginning_of_day rescue ""
    end

    if !params[:search][:completed_at_less_than].blank?
      params[:search][:completed_at_less_than] = Time.zone.parse(params[:search][:completed_at_less_than]).end_of_day rescue ""
    end

    params[:search][:order] ||= "descend_by_completed_at"
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
      render :edit
    end
  end

end
