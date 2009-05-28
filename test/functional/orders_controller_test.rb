require 'test_helper'

class OrdersControllerTest < ActionController::TestCase
  fixtures :countries, :states
  
  context "on POST to :checkout" do
    setup do        
      session[:order_id] = Factory(:order).id 
      post :checkout, :final_answer => true, 
                      :order => {:bill_address_attributes => {},
                                 :ship_address_attributes => {},
                                 :creditcards_attributes => {0 => Factory.attributes_for(:creditcard)} }
    end
    should_respond_with :success
    should_change "Creditcard.count", :from => 0, :to => 1
    should_redirect_to "orders_url(@order)"
  end
end