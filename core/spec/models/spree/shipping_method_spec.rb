require 'spec_helper'

class DummyShippingCalculator < Spree::ShippingCalculator
end

describe Spree::ShippingMethod, :type => :model do
  let(:shipping_method){ create(:shipping_method) }

  context 'calculators' do
    it "Should reject calculators that don't inherit from Spree::ShippingCalculator" do
      allow(Spree::ShippingMethod).to receive_message_chain(:spree_calculators, :shipping_methods).and_return([
        Spree::Calculator::Shipping::FlatPercentItemTotal,
        Spree::Calculator::Shipping::PriceSack,
        Spree::Calculator::DefaultTax,
        DummyShippingCalculator # included as regression test for https://github.com/spree/spree/issues/3109
      ])

      expect(Spree::ShippingMethod.calculators).to eq([Spree::Calculator::Shipping::FlatPercentItemTotal, Spree::Calculator::Shipping::PriceSack, DummyShippingCalculator ])
      expect(Spree::ShippingMethod.calculators).not_to eq([Spree::Calculator::DefaultTax])
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
      expect(shipping_method.shipments).to include(shipment)
    end
  end

  context "validations" do
    before { subject.valid? }

    it "validates presence of name" do
      expect(subject.error_on(:name).size).to eq(1)
    end

    context "shipping category" do
      it "validates presence of at least one" do
        expect(subject.error_on(:base).size).to eq(1)
      end

      context "one associated" do
        before { subject.shipping_categories.push create(:shipping_category) }
        it { expect(subject.error_on(:base).size).to eq(0) }
      end
    end
  end

  context 'factory' do
    it "should set calculable correctly" do
      expect(shipping_method.calculator.calculable).to eq(shipping_method)
    end
  end

  context "generating tracking URLs" do
    context "shipping method has a tracking URL mask on file" do
      let(:tracking_url) { "https://track-o-matic.com/:tracking" }
      before { allow(subject).to receive(:tracking_url) { tracking_url } }

      context 'tracking number has spaces' do
        let(:tracking_numbers) { ["1234 5678 9012 3456", "a bcdef"] }
        let(:expectations) { %w[https://track-o-matic.com/1234%205678%209012%203456 https://track-o-matic.com/a%20bcdef] }

        it "should return a single URL with '%20' in lieu of spaces" do
          tracking_numbers.each_with_index do |num, i|
            expect(subject.build_tracking_url(num)).to eq(expectations[i])
          end
        end
      end
    end
  end

  # Regression test for #4320
  context "soft deletion" do
    let(:shipping_method) { create(:shipping_method) }
    it "soft-deletes when destroy is called" do
      shipping_method.destroy
      expect(shipping_method.deleted_at).not_to be_blank
    end
  end
end
