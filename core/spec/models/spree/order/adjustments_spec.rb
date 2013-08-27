require 'spec_helper'
describe Spree::Order do
  let(:order) { Spree::Order.new }

  context "totaling adjustments" do
    let(:adjustment1) { create(:adjustment, :amount => 5) }
    let(:adjustment2) { create(:adjustment, :amount => 10) }

    context "#tax_total" do
      it "should return the correct amount" do
        order.adjustments += [adjustment1, adjustment2]
        order.save
        order.tax_total.should == 15
      end
    end
  end
end
