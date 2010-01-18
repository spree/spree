require 'test_helper'

class Admin::CreditcardsControllerTest < ActionController::TestCase
  fixtures :gateways

  context "given order" do
    setup do
      UserSession.create(Factory(:admin_user))
      create_new_order
      @order.reload
      @creditcard = @order.creditcards.first      
    end

    context "GET index" do
      setup do
        get :index, :order_id => @order.id
      end
      should_assign_to :creditcards
      should_respond_with :success
    end
    
    context "GET refund" do
      setup do
        get :refund, :order_id => @order.id, :id => @creditcard.id
      end
      should_respond_with :success
    end
    
    context "POST refund" do
      setup do
        @order.line_items << Factory(:line_item, :quantity => 1, :price => 5.00)
        # Create an outstanding credit so payment will validate by increasing amount of the order's creditcard payment
        @order.creditcard_payments.first.update_attribute(:amount, @order.total + 5.00)
        @order.reload
        @order.save

        @creditcard_txn = @creditcard.creditcard_txns.first
        post :refund, :order_id => @order.id, :id => @order.creditcards.first.id, :amount => '5.00', :txn_id => @creditcard_txn.id
      end
      should_change("CreditcardTxn.count", :by => 1) { CreditcardTxn.count }
      should_respond_with :redirect      
      should "have new transaction with the right attributes" do
        assert_equal -5.00, @creditcard.creditcard_txns.last.amount.to_f
      end
    end
    
  end

end
