require 'test_helper'

class OrderTest < ActiveSupport::TestCase
  
  context "create" do
    setup { Order.create }
    should_change "Checkout.count", :by => 1
  end   
  
  context "instance" do
    setup do
      @order = Factory(:order)
    end
    context "complete" do
      setup { @order.complete }
      should_change "@order.state", :from => "in_progress", :to => "new"
    end
  end
  
end