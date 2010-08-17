require 'spec_helper'

describe InventoryUnit do
  let(:variant) { mock_model(Variant) }

  context "#fill_backorder (when in backordered state)" do
    it "should change state to sold" do
      unit = InventoryUnit.new(:variant => variant, :state => "backordered")
      unit.fill_backorder
      unit.state.should == "sold"
    end
  end

  let(:line_item) { mock_model(LineItem, :variant => variant, :quantity => 1) }
  context "adjust_units" do
    it "should restock units if a line item is removed from the order"
    it "should sell more units if a line item has an increased in quantity"
    it "should restock units if a line item has an decreased in quantity"
  end

  context "sell_units" do
    it "should increase the number of inventory units by the expected amount"
    it "should correctly set the state of in-stock units"
    it "should correctly set the state of out-of-stock units"
    it "should do nothing if all units in the order were already sold (saftey check for unexpected condition)"
  end
end