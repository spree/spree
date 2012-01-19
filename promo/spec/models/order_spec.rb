require File.dirname(__FILE__) + '/../spec_helper'

describe Order do

  describe "process_automatic_promotions" do
    
    describe "if eligible and promo amount exceeds order line item total" do
      let(:calculator) { Calculator::FlatPercentItemTotal.new }
      let(:promotion) { Promotion.new(:usage_limit => 1, :calculator => calculator) }
      let(:promotion_credit) { PromotionCredit.new(:source => promotion) }
      let(:order) { Order.new }
      let(:item_total) { 20 }
      before {
        order.stub(:item_total => item_total)
        promotion.stub(:eligible? => true)
        calculator.stub(:compute => 100)
        order.promotion_credits = [promotion_credit]
      }
      after {
        order.process_automatic_promotions
      }

      it "it should provide a promotion amount equal to line item total" do
        PromotionCredit.should_receive(:update_all).with("amount = #{-item_total}", { :id => promotion_credit.id })
      end
    end
  end
end