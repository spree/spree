require 'spec_helper'

describe Shipment do
  let(:shipment) { Shipment.new }
  let(:charge) { mock_model Adjustment, :amount => 10, :source => shipment }

  context "#cost" do

    it "should return the amount of any shipping charges that it originated" do
      shipment.stub_chain :order, :adjustments, :shipping => [charge]
      shipment.cost.should == 10
    end

    it "should return 0 if there are no relevant shipping adjustments" do
      shipment.stub_chain :order, :adjustments, :shipping => []
      shipment.cost.should == 0
    end

  end
end