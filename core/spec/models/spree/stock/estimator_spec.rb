require 'spec_helper'

module Spree
  module Stock
    describe Estimator do
      let!(:shipping_method) { create(:shipping_method_with_category) }
      let(:shipping_category) { shipping_method.shipping_categories.first }
      let(:package) { build(:stock_package_fulfilled) }
      let(:order) { package.order }
      subject { Estimator.new(order) }

      context "#shipping rates" do
        before(:each) do
          shipping_method.zones.first.members.create(:zoneable => order.ship_address.country)
          ShippingMethod.any_instance.stub_chain(:calculator, :available?).and_return(true)
          ShippingMethod.any_instance.stub_chain(:calculator, :compute).and_return(4.00)
          ShippingMethod.any_instance.stub_chain(:calculator, :preferences).and_return({:currency => "USD"})
        end

        it "returns shipping rates from a shipping method if the order's ship address is in the same zone" do
          package.should_receive(:shipping_category).and_return(shipping_category)

          shipping_rates = subject.shipping_rates(package)
          shipping_rates.first.cost.should eq 4.00
        end

        it "does not return shipping rates from a shipping method if the order's ship address is in a different zone" do
          shipping_method.zones.each{|z| z.members.delete_all}
          package.should_receive(:shipping_category).and_return(shipping_category)

          shipping_rates = subject.shipping_rates(package)
          shipping_rates.should == []
        end

        it "does not return shipping rates from a shipping method if the calculator is not available for that order" do
          ShippingMethod.any_instance.stub_chain(:calculator, :available?).and_return(false)
          package.should_receive(:shipping_category).and_return(shipping_category)

          shipping_rates = subject.shipping_rates(package)
          shipping_rates.should == []
        end

        it "returns shipping rates from a shipping method if the currency matches the order's currency" do
          package.should_receive(:shipping_category).and_return(shipping_category)

          shipping_rates = subject.shipping_rates(package)
          shipping_rates.first.cost.should eq 4.00
        end

        it "does not return shipping rates from a shipping method if the currency is different than the order's currency" do
          order.currency = "GBP"
          package.should_receive(:shipping_category).and_return(shipping_category)

          shipping_rates = subject.shipping_rates(package)
          shipping_rates.should == []
        end
      end
    end
  end
end
