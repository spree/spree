class Admin::OrdersController < Admin::BaseController
  
  before_filter :initialize_txn_partials
  
  in_place_edit_for :address, :firstname
  in_place_edit_for :address, :lastname
  in_place_edit_for :address, :address1
  in_place_edit_for :address, :address2
  in_place_edit_for :address, :city
  in_place_edit_for :address, :zipcode
  in_place_edit_for :address, :phone
  in_place_edit_for :user, :email
  
  def index
    @status_options = Order::Status.constants
    if params[:search]
      @search = SearchCriteria.new(params[:search])
      if @search.valid?
        p = {}
        conditions = build_conditions(p)
        if p.empty? 
          @orders = Order.find(:all, :order => "created_at DESC", :include => [:address, :line_items], :page => {:size => 15, :current =>params[:page], :first => 1})          
        else 
          @orders = Order.find(:all, 
                               :order => "orders.created_at DESC",
                               :joins => "as orders inner join addresses as a on orders.bill_address_id = a.id",
                               :conditions => [conditions, p],
                               :select => "orders.*",
                               :include => [:address, :line_items], 
                               :page => {:size => 15, :current =>params[:page], :first => 1})
        end
      else
        @orders = []
        flash.now[:error] = "Invalid search criteria.  Please check your results."      
      end
    else
      @search = SearchCriteria.new
      @orders = Order.find(:all, 
                           :order => "created_at DESC",
                           :conditions => ["status != ?", Order::Status::INCOMPLETE],
                           :include => [:address, :line_items], 
                           :page => {:size => 15, :current =>params[:page], :first => 1})
    end
  end
  
  def show
    @order = Order.find(params[:id])
    @user = @order.user
    @states = State.find(:all)
    @countries = Country.find(:all)
  end

  def capture
    order = Order.find(params[:id])
    begin
      order.creditcard_payment.capture
      flash[:notice] = "Order has been captured."    
      order.status = Order::Status::CAPTURED
      order.order_operations << OrderOperation.new(
        :operation_type => OrderOperation::OperationType::CAPTURE,
        :user => current_user
      )
      order.save
    rescue SecurityError => se
      flash[:error] = "Authorization Error: #{se.message}"
    ensure
      redirect_to :back
    end
  end
  
  def ship
    begin
      order = Order.find(params[:id])    
      order.ship
      order.order_operations.create(:operation_type => OrderOperation::OperationType::SHIP, :user => current_user)
      flash[:notice] = "Order has been shipped."    
    rescue
      # TODO capture gateway errors, etc.
      logger.error "unable to ship order: " + order.inspect
      flash[:error] = "Unable to ship order.  Please contact your administrator."
    end    
    
    redirect_to :back
  end
  
  def cancel
    order = Order.find(params[:id])
    begin
      order.cancel
      order.order_operations.create(:operation_type => OrderOperation::OperationType::CANCEL, :user => current_user)
      flash[:notice] = "Order has been cancelled."    
    rescue SecurityError => se
      flash[:error] = "Gateway Cancellation Error: #{se.message}"
    end
    # send email confirmation
    #OrderMailer.deliver_cancel(order)
    redirect_to :back
  end

  def return
    order = Order.find(params[:id])
    order.return
    flash[:notice] = "Order successfully returned."    
    flash[:warn] = "Warning: Creditcard has not been credited.  Please do so manually in your gateway."
    order.order_operations.create (:operation_type => OrderOperation::OperationType::RETURN, :user => current_user)
    # TODO: log errors, etc.
    redirect_to :back
  end
  
  def resend
    # resend the order receipt
=begin    
    @order = Order.find(params[:id])
    OrderMailer.deliver_confirm(@order, true)
    flash[:notice] = "Confirmation message was resent successfully."
    redirect_to :back
=end
  end

  def delete
    # delete an incomplete order from the system
    order = Order.find(params[:id])
    if order.destroy
      flash[:notice] = "Order successfully deleted."    
    else
      logger.error "unable to delete order: " + order.inspect
      flash[:error] = "Unable to delete order."
    end
    redirect_to :back
  end

  private

    # Allows extensions to add new forms of payment to provide their own display of transactions
    def initialize_txn_partials
      @txn_partials = []
    end
    
    def gateway_void(order)
      authorization = find_authorization(order)
      gw = payment_gateway
      response = gw.void(authorization.response_code, Order.minimal_gateway_options(order))
      return unless response.success?
      order.credit_card.txns << CreditcardTxn.new(
        :amount => order.total,
        :response_code => response.authorization,
        :txn_type => CreditcardTxn::TxnType::VOID
      )
      order.save
      response
    end
   
    def gateway_credit(order)
      authorization = find_authorization(order)
      gw = payment_gateway
      response = gw.credit(order.total, authorization.response_code, Order.minimal_gateway_options(order))
      return unless response.success?
      order.credit_card.txns << CreditcardTxn.new(
        :amount => order.total,
        :response_code => response.authorization,
        :txn_type => CreditcardTxn::TxnType::CREDIT
      )
      order.save
      response
    end

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

end
