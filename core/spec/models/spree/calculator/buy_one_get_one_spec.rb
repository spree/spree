require 'spec_helper'
describe Spree::Calculator::BuyOneGetOne do
	let!(:product1) { double("Product") }  
  let!(:line_items) { [double("LineItem", :quantity => 1, :product => product1, :price => 10)] }
  let!(:promotion) { double("Promotion", :rules => [double("Rule", :products => [product1.respond_to?(:is_gift_card?) ? (not product1.is_gift_card?) : true ])]) }
	let!(:object) { double("Order", :line_items => line_items) }
	let!(:calculator) { Spree::Calculator::BuyOneGetOne.new(:preferred_number_to_buy => 1, :preferred_number_to_get => 1) }
	
		it "has a translation for description" do
	    calculator.description.should_not include("translation missing")
	    calculator.description.should == Spree.t(:buy_x_get_y)
  	end

  	it "computes on promotion when promotion is present" do
	    calculator.send(:compute_on_promotion?).should_not be_true
	    calculator.stub(:calculable => promotion_calculable)
	    calculator.send(:compute_on_promotion?).should be_true
  	end

  	it "correctly calculates per item promotion" do
    	calculator.stub(:calculable => promotion_calculable)
    	calculator.compute(object).to_f.should == 20
  	end
end
