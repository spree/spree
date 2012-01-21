require 'spec_helper'

describe Spree::Calculator::WeightRate do
  let(:calculator) { Spree::Calculator::WeightRate.new }
  let(:order) { mock_model Spree::Order, :line_items => [mock_model(Spree::LineItem, :amount => 10, :quantity => 4), mock_model(Spree::LineItem, :amount => 20, :quantity => 6)] }

  context "compute" do
    it "should show correct defaut price" do
      calculator.stub :preferred_default_price => 10.0
      calculator.compute(order).round(2).should == 10.0
    end

    it "should show correct amount with rule and defaut weight #1" do
      calculator.stub :preferred_default_rule => "1:4;2:5;3:10;4:14;10:30;20:70;40:120;100:150"
      calculator.stub :preferred_default_weight => 1

      variant1 = mock_model(Spree::Variant, :product => "product1")
      variant2 = mock_model(Spree::Variant, :product => "product2")
      line_items = [mock_model(Spree::LineItem, :variant => variant1, :quantity => 4), mock_model(Spree::LineItem, :variant => variant2, :quantity => 2)]
      order.stub(:line_items => line_items)

      calculator.compute(order).round(2).should == 30.0
    end

    it "should show correct amount with rule and defaut weight #2" do
      calculator.stub :preferred_default_rule => "1:4;2:5;3:10;4:14;10:30;20:70;40:120;100:150"
      calculator.stub :preferred_default_weight => 1.9

      variant1 = mock_model(Spree::Variant, :product => "product1")
      variant2 = mock_model(Spree::Variant, :product => "product2")
      line_items = [mock_model(Spree::LineItem, :variant => variant1, :quantity => 4), mock_model(Spree::LineItem, :variant => variant2, :quantity => 2)]
      order.stub(:line_items => line_items)

      calculator.compute(order).round(2).should == 70.0
    end

    it "should show correct amount with rule and variant weight" do
      calculator.stub :preferred_default_rule => "1:4;2:5;3:10;4:14;10:30;20:70;40:120;100:150"

      variant1 = mock_model(Spree::Variant, :product => "product1", :weight => 0.4)
      variant2 = mock_model(Spree::Variant, :product => "product2", :weight => 1.1)
      line_items = [mock_model(Spree::LineItem, :variant => variant1, :quantity => 4), mock_model(Spree::LineItem, :variant => variant2, :quantity => 2)]
      order.stub(:line_items => line_items)

      calculator.compute(order).round(2).should == 14.0
    end

    it "should show correct amount with rule and variant weight and default weight" do
      calculator.stub :preferred_default_rule => "1:4;2:5;3:10;4:14;10:30;20:70;40:120;100:150"
      calculator.stub :preferred_default_weight => 1

      variant1 = mock_model(Spree::Variant, :product => "product1", :weight => 0.2)
      variant2 = mock_model(Spree::Variant, :product => "product2")
      line_items = [mock_model(Spree::LineItem, :variant => variant1, :quantity => 4), mock_model(Spree::LineItem, :variant => variant2, :quantity => 2)]
      order.stub(:line_items => line_items)

      calculator.compute(order).round(2).should == 10.0
    end

  end


end
