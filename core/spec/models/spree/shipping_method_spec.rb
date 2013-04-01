require 'spec_helper'

describe Spree::ShippingMethod do
  context 'calculators' do
  
    it "Should reject calculators that don't inherit from Spree::Calculator::Shipping::" do
      calculators = Rails.stub_chain(:application, :config, :spree, :calculators, :send).and_return [
            Spree::Calculator::Shipping::FlatPercentItemTotal,
            Spree::Calculator::Shipping::PriceSack,
            Spree::Calculator::DefaultTax]
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
