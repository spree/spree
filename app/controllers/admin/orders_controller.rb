class Admin::OrdersController < Admin::BaseController
  require 'spree/gateway_error'
  resource_controller
  before_filter :initialize_txn_partials
  before_filter :load_object, :only => :fire

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
  
  private
  def collection    
    @collection ||= end_of_association_chain.find(:all, :order => :created_at, :include => :user,
      :page => {:size => 15, :current =>params[:page], :first => 1})
  end
  
  # Allows extensions to add new forms of payment to provide their own display of transactions
  def initialize_txn_partials
    @txn_partials = []
  end
=begin    
    def build_conditions(p)
      c = []
      if not @search.start.blank?
        c << "(orders.created_at between :start and :stop)"
        p.merge! :start => @search.start.to_date
        @search.stop = Date.today + 1 if @search.stop.blank?
        p.merge! :stop => @search.stop.to_date + 1.day 
      end
      unless @search.order_num.blank?
        c << "number like :order_num"
        p.merge! :order_num => @search.order_num + "%"
      end
      unless @search.customer.blank?
        c << "(firstname like :customer or lastname like :customer)"
        p.merge! :customer => @search.customer + "%"
      end
      if @search.status
        c << "status = :status"
        p.merge! :status => @search.status
      end
      (c.to_sentence :skip_last_comma=>true).gsub(",", " and ")
    end
=end
end
