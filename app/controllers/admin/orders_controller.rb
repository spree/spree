class Admin::OrdersController < Admin::BaseController
  
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
          @orders = Order.find(:all, :order => "created_at DESC", :page => {:size => 15, :current =>params[:page], :first => 1})          
        else 
          @orders = Order.find(:all, 
                               :order => "orders.created_at DESC",
                               :joins => "as orders inner join addresses as a on orders.bill_address_id = a.id",
                               :conditions => [conditions, p],
                               :select => "orders.*",
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
                           :page => {:size => 15, :current =>params[:page], :first => 1})
    end
  end
  
  def show
    @order = Order.find(params[:id])
    @user = @order.user
    @states = State.find(:all)
    @countries = Country.find(:all)
    @cc_txns = Txn.credit_card @order.credit_card if @order.credit_card
  end

  def capture
    order = Order.find(params[:id])

    response = gateway_capture(order)
    unless response.success?
      flash[:error] = "Problem capturing credit card ... \n#{response.params['error']}"   
      redirect_to :back and return
    end

    order.status = Order::Status::CAPTURED
    order.order_operations << OrderOperation.new(
      :operation_type => OrderOperation::OperationType::CAPTURE,
      :user => current_user
    )

    if order.save
      flash[:notice] = "Order has been captured."    
    else
      logger.error "unable to update order status: " + order.inspect
      flash[:error] = "Order was captured but database update has failed.  Please ask your administrator to manually adjust order status."
    end
    redirect_to :back
  end
  
  def ship
    order = Order.find(params[:id])
    
    # if the current status is AUTHORIZED then we need to CAPTURE as well
    if order.status == Order::Status::AUTHORIZED
      response = gateway_capture(order)
      unless response.success?
        flash[:error] = "Problem capturing credit card ... \n#{response.params['error']}"   
        redirect_to :back and return
      end
    end
    
    order.status = Order::Status::SHIPPED
    order.order_operations << OrderOperation.new(
      :operation_type => OrderOperation::OperationType::SHIP,
      :user => current_user
    )

    begin 
      Order.transaction do
        order.save!
        # now update the inventory to reflect the new shipped status
        order.inventory_units.each do |unit|     
          unit.update_attributes(:status => InventoryUnit::Status::SHIPPED)
        end
      end
      flash[:notice] = "Order has been shipped."    
    rescue
      logger.error "unable to ship order: " + order.inspect
      flash[:error] = "Unable to ship order.  Please contact your administrator."
    end    
    
    redirect_to :back
    
  end
  
  def cancel
    order = Order.find(params[:id])
    response = gateway_void(order)

    unless response.success?
      flash[:error] = "Problem voiding credit card authorization ... \n#{response.params['error']}"   
      redirect_to :back and return
    end

    order.order_operations << OrderOperation.new(
      :operation_type => OrderOperation::OperationType::CANCEL,
      :user => current_user
    )
    order.status = Order::Status::CANCELED
    
    begin 
      Order.transaction do
        order.save!
        # now update the inventory to reflect the new on hand status
        order.inventory_units.each do |unit|     
          unit.update_attributes(:status => InventoryUnit::Status::ON_HAND)
        end
        flash[:notice] = "Order cancelled successfully."    
      end
    rescue
      logger.error "unable to cancel order: " + order.inspect
      flash[:error] = "Unable to cancel order."
    end    
    # send email confirmation
    OrderMailer.deliver_cancel(order)
    
    redirect_to :back
  end

  def return
    order = Order.find(params[:id])
    
    # TODO - consider making the credit an option since it may not be supported by some gateways
    response = gateway_credit(order)

    unless response.success?
      flash[:error] = "Problem crediting the credit card ... \n#{response.params['error']}"   
      redirect_to :back and return
    end

    order.order_operations << OrderOperation.new(
      :operation_type => OrderOperation::OperationType::RETURN,
      :user => current_user
    )
    order.status = Order::Status::RETURNED
    
    begin
      Order.transaction do
        order.save!
        # now update the inventory to reflect the new on hand status
        order.inventory_units.each do |unit|     
          unit.update_attributes(:status => InventoryUnit::Status::ON_HAND)
        end
        flash[:notice] = "Order successfully returned."    
      end
    rescue
      logger.error "unable to return order: " + order.inspect
      flash[:error] = "Order payment was credited but database update has failed.  Please ask your administrator to manually adjust order status."
    end
    
    redirect_to :back
  end
  
  def resend
    # resend the order receipt
    @order = Order.find(params[:id])
    OrderMailer.deliver_confirm(@order, true)
    flash[:notice] = "Confirmation message was resent successfully."
    redirect_to :back
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
      def gateway_capture(order)
        authorization = find_authorization(order)
        gw = payment_gateway
        response = gw.capture(order.total * 100, authorization.response_code, Order.minimal_gateway_options(order))
        return unless response.success?
        order.credit_card.txns << Txn.new(
          :amount => order.total,
          :response_code => response.authorization,
          :txn_type => Txn::TxnType::CAPTURE
        )
        order.save
        response
      end
      
      def gateway_void(order)
        authorization = find_authorization(order)
        gw = payment_gateway
        response = gw.void(authorization.response_code, Order.minimal_gateway_options(order))
        return unless response.success?
        order.credit_card.txns << Txn.new(
          :amount => order.total,
          :response_code => response.authorization,
          :txn_type => Txn::TxnType::VOID
        )
        order.save
        response
      end
     
      def gateway_credit(order)
        authorization = find_authorization(order)
        gw = payment_gateway
        response = gw.credit(order.total, authorization.response_code, Order.minimal_gateway_options(order))
        return unless response.success?
        order.credit_card.txns << Txn.new(
          :amount => order.total,
          :response_code => response.authorization,
          :txn_type => Txn::TxnType::CREDIT
        )
        order.save
        response
      end

      def find_authorization(order)
        #find the transaction associated with the original authorization/capture 
        cc = order.credit_card
        cc.txns.find(:first, 
                     :conditions => ["txn_type = ? or txn_type = ?", Txn::TxnType::AUTHORIZE, Txn::TxnType::CAPTURE],
                     :order => 'created_at DESC')
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
