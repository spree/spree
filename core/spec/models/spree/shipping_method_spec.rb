require 'spec_helper'

class DummyShippingCalculator < Spree::ShippingCalculator
end

describe Spree::ShippingMethod do
  context 'calculators' do
    let(:shipping_method){ create(:shipping_method) }

    it "Should reject calculators that don't inherit from Spree::ShippingCalculator" do
      Spree::ShippingMethod.stub_chain(:spree_calculators, :shipping_methods).and_return([
        Spree::Calculator::Shipping::FlatPercentItemTotal,
        Spree::Calculator::Shipping::PriceSack,
        Spree::Calculator::DefaultTax,
        DummyShippingCalculator # included as regression test for https://github.com/spree/spree/issues/3109
      ])

      Spree::ShippingMethod.calculators.should == [Spree::Calculator::Shipping::FlatPercentItemTotal, Spree::Calculator::Shipping::PriceSack, DummyShippingCalculator ]
      Spree::ShippingMethod.calculators.should_not == [Spree::Calculator::DefaultTax]
    end
  end

  context "validations" do
    before { subject.valid? }

    it "validates presence of name" do
      subject.should have(1).error_on(:name)
    end

    context "shipping category" do
      it "validates presence of at least one" do
        subject.should have(1).error_on(:base)
      end

      context "one associated" do
        before { subject.shipping_categories.push create(:shipping_category) }
        it { subject.should have(0).error_on(:base) }
      end
    end
  end

  context 'factory' do
    let(:shipping_method){ create :shipping_method }

    it "should set calculable correctly" do
      shipping_method.calculator.calculable.should == shipping_method
    end
  end
end
