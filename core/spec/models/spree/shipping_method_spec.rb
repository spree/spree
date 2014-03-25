require 'spec_helper'

describe Spree::ShippingMethod do
  context 'calculators' do
    let(:shipping_method){ create(:shipping_method) }

    it "Should reject calculators that don't inherit from Spree::Calculator::Shipping::" do
      Spree::ShippingMethod.stub_chain(:spree_calculators, :shipping_methods).and_return([
            Spree::Calculator::Shipping::FlatPercentItemTotal,
            Spree::Calculator::Shipping::PriceSack,
            Spree::Calculator::DefaultTax])
      Spree::ShippingMethod.calculators.should == [Spree::Calculator::Shipping::FlatPercentItemTotal, Spree::Calculator::Shipping::PriceSack ]
      Spree::ShippingMethod.calculators.should_not == [Spree::Calculator::DefaultTax]
    end
  end

  # Regression test for #4492
  context "#shipments" do
    let!(:shipping_method) { create(:shipping_method) }
    let!(:shipment) do
      shipment = create(:shipment)
      shipment.shipping_rates.create!(:shipping_method => shipping_method)
      shipment
    end

    it "can gather all the related shipments" do
      shipping_method.shipments.should include(shipment)
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

  context "generating tracking URLs" do
    context "shipping method has a tracking URL mask on file" do
      let(:tracking_url) { "https://track-o-matic.com/:tracking" }
      before { subject.stub(:tracking_url) { tracking_url } }

      context 'tracking number has spaces' do
        let(:tracking_numbers) { ["1234 5678 9012 3456", "a bcdef"] }
        let(:expectations) { %w[https://track-o-matic.com/1234%205678%209012%203456 https://track-o-matic.com/a%20bcdef] }

        it "should return a single URL with '%20' in lieu of spaces" do
          tracking_numbers.each_with_index do |num, i|
            subject.build_tracking_url(num).should == expectations[i]
          end
        end
      end
    end
  end
end
