require 'spec_helper'

describe Spree::Calculator::FlexiRate do
  let(:calculator) { Spree::Calculator::FlexiRate.new }
  let(:order) { mock_model Spree::Order, :line_items => [mock_model(Spree::LineItem, :amount => 10, :quantity => 4), mock_model(Spree::LineItem, :amount => 20, :quantity => 6)] }

  context "compute" do
    it "should compute amount correctly when all fees are 0" do
      calculator.compute(order).round(2).should == 0.0
    end

    it "should compute amount correctly when first_item has a value" do
      calculator.stub :preferred_first_item => 1.0
      calculator.compute(order).round(2).should == 1.0
    end

    it "should compute amount correctly when additional_items has a value" do
      calculator.stub :preferred_additional_item => 1.0
      calculator.compute(order).round(2).should == 9.0
    end

    it "should compute amount correctly when additional_items and first_item have values" do
      calculator.stub :preferred_first_item => 5.0, :preferred_additional_item => 1.0
      calculator.compute(order).round(2).should == 14.0
    end

    it "should compute amount correctly when additional_items and first_item have values AND max items has value" do
      calculator.stub :preferred_first_item => 5.0, :preferred_additional_item => 1.0, :preferred_max_items => 3
      calculator.compute(order).round(2).should == 26.0
    end

    it "should allow creation of new object with all the attributes" do
      Spree::Calculator::FlexiRate.new(:preferred_first_item => 1, :preferred_additional_item => 1, :preferred_max_items => 1)
    end
  end
end
