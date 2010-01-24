require 'test_helper'

class Admin::CreditcardTxnsControllerTest < ActionController::TestCase
  fixtures :gateways

  context "given creditcard" do
    setup do
      UserSession.create(Factory(:admin_user))
      create_new_order
      @order.reload
      @creditcard = @order.creditcards.first      
    end

    context "POST to :void" do
      setup do
        @txn_to_void = @creditcard.txns.first
        post :void, :id => @txn_to_void.id
      end
      #should_respond_with :redirect
    end
        
  end

end
