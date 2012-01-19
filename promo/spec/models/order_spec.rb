require File.dirname(__FILE__) + '/../spec_helper'

describe Order do
  let(:order) { Order.new }
  
  describe "finalized?" do
    let(:finalized_states) { ["complete", "awaiting_return", "returned"] }
    
    it "should return true" do
      finalized_states.each do |state|
        order.state = state
        order.finalized?.should == true
      end
    end
    
    it "should return false" do
      (Order.state_machine.states.map(&:name) - Order.finalized_states).each do |state|
        order.state = state
        order.finalized?.should == false
      end
    end
    
  end
  
  describe "update_totals" do
    after {
      order.update_totals
    }

    describe "when order finalized" do
      before {
        # finalized? is a method that states whether Order is
        order.stub(:finalized? => true)
      }
  
      it "should not process automatic promotions" do
        order.should_not_receive(:process_automatic_promotions)
      end
  
    end

    describe "when not finalized" do
      before {
        order.stub(:finalized? => false)
      }
  
      it "should process automatic promotions" do
        order.should_receive(:process_automatic_promotions)
      end
  
    end
  end
end