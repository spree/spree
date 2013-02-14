require 'spec_helper'

describe Spree::Calculator::FlatPercentItemTotal do
  let(:calculator) { Spree::Calculator::FlatPercentItemTotal.new }
  let(:order) { mock_model Spree::Order }

  before { calculator.stub :preferred_flat_percent => 10 }

  context "compute" do
    it "should round result correctly" do
      order.stub :item_total => 31.08
      calculator.compute(order).should == 3.11

      order.stub :item_total => 31.00
      calculator.compute(order).should == 3.10
    end
  end
end
