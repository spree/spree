require 'spec_helper'

describe Spree::ShippingMethod do

  context 'calculators' do
    let(:shipping_method){ create :shipping_method}

    it "Should reject calculators that don't inherit from Spree::Calculator::Shipping::" do
      Spree::ShippingMethod.stub_chain(:spree_calculators, :shipping_methods).and_return([
            Spree::Calculator::Shipping::FlatPercentItemTotal,
            Spree::Calculator::Shipping::PriceSack,
            Spree::Calculator::DefaultTax])
      Spree::ShippingMethod.calculators.should == [Spree::Calculator::Shipping::FlatPercentItemTotal, Spree::Calculator::Shipping::PriceSack ]
      Spree::ShippingMethod.calculators.should_not == [Spree::Calculator::DefaultTax]
    end
  end

  context 'factory' do
    let(:shipping_method){ create :shipping_method }

    it "should set calculable correctly" do
      shipping_method.calculator.calculable.should == shipping_method
    end
  end
end
