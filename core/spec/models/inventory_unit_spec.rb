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
    let(:line_items){
      (1..3).map do |n| 
        line_item = mock_model(LineItem, :variant => mock_model(Variant, :count_on_hand => n, :update_attribute => true), :quantity => n)
      end
    }
    let(:order) { mock_model(Order, :line_items => line_items, :inventory_units => mock('inventory-units'), :complete? => false) }

    it "should increase the number of inventory units by the expected amount" do
      order.inventory_units.should_receive(:create).exactly(6).times
      InventoryUnit.sell_units(order)
    end
    it "should not increase the number of inventory units if the order is completed" do
      order.stub!(:complete?).and_return(true)
      order.inventory_units.should_not_receive(:create)
      InventoryUnit.sell_units(order)
    end
    it "should return array of out of stock items" do
      Spree::Config.set :allow_backorders => false
      order.line_items.first.variant.stub!(:count_on_hand).and_return(0)
      order.inventory_units.should_receive(:create).exactly(5).times
      out_of_stock_items = InventoryUnit.sell_units(order)
      out_of_stock_items.length.should == 1 
      out_of_stock_items.first[:line_item].should == order.line_items.first
    end
    it "should correctly set the state of in-stock units"
    it "should correctly set the state of out-of-stock units"
    it "should do nothing if all units in the order were already sold (saftey check for unexpected condition)"
  end

end
