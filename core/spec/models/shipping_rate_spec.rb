# encoding: utf-8

require 'spec_helper'

describe Spree::ShippingRate do
  let(:shipping_rate) { Spree::ShippingRate.new(:cost => 10.55) }
  before { Spree::TaxRate.stub(:default => 0.05) }

  context "#display_price" do
    context "when shipment includes VAT" do
      before { Spree::Config[:shipment_inc_vat] = true }
      it "displays the correct price" do
        shipping_rate.display_price.to_s.should == "$11.08" # $10.55 * 1.05 == $11.08
      end
    end

    context "when shipment does not include VAT" do
      before { Spree::Config[:shipment_inc_vat] = false }
      it "displays the correct price" do
        shipping_rate.display_price.to_s.should == "$10.55"
      end
    end

    context "when the currency is JPY" do
      let(:shipping_rate) { Spree::ShippingRate.new(:cost => 205, :currency => "JPY") }

      it "displays the price in yen" do
        shipping_rate.display_price.to_s.should == "¥205"
      end
    end
  end
end
