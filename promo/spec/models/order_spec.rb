require 'spec_helper'

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
  
  describe "process_automatic_promotions" do
    describe "if eligible and promo amount exceeds order line item total" do
      let(:promotion) { Promotion.new(:usage_limit => 1, :calculator => stub(:compute => 100)) }
      let(:promotion_credit) { PromotionCredit.new(:source => promotion) }
      let(:order) { Order.new }
      let(:item_total) { 20 }

      before do
        order.stub(:item_total => item_total)
        promotion.stub(:eligible? => true)
        order.promotion_credits = [promotion_credit]
      end

      it "it should provide a promotion amount equal to line item total" do
        PromotionCredit.should_receive(:update_all).with("amount = #{-item_total}", { :id => promotion_credit.id })
        order.process_automatic_promotions
      end
    end
  end
end
