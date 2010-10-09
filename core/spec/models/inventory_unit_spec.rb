require 'spec_helper'

describe InventoryUnit do
  let(:variant) { mock_model(Variant, :count_on_hand => 99) }
  let(:line_items){
    (1..3).map do |n|
      line_item = mock_model(LineItem, :variant => mock_model(Variant, :count_on_hand => n, :update_attribute => true), :quantity => n)
    end
  }

  context "#fill_backorder (when in backordered state)" do
    it "should change state to sold" do
      unit = InventoryUnit.new(:variant => variant, :state => "backordered")
      unit.fill_backorder
      unit.state.should == "sold"
    end
  end

  let(:shipment) { mock_model(Shipment, :shipped? => false) }

  context "adjust_units" do
    before do
      Spree::Config.set :track_inventory_levels => true
    end
    let(:line_item) { mock_model(LineItem, :variant => variant, :quantity => 1) }
    let(:inventory_unit) { InventoryUnit.new(:variant => variant, :shipment => shipment, :state => "sold") }
    let(:order) { mock_model(Order, :line_items => [line_item], :inventory_units => [inventory_unit], :shipments => [shipment], :completed? => true) }

    it "should restock units if a line item is removed from the order" do
      order.stub(:line_items).and_return([])
      variant.should_receive(:update_attribute).with(:count_on_hand, variant.count_on_hand + 1)
      inventory_unit.should_receive(:delete)
      InventoryUnit.adjust_units(order)
    end

    it "should sell more units if a line item has an increased in quantity" do
      line_item.stub :quantity => 2
      order.inventory_units.should_receive(:create).with(:state => "sold", :variant => line_item.variant, :shipment => shipment).exactly(1).times
      variant.should_receive(:update_attribute).with(:count_on_hand, variant.count_on_hand - 1)
      InventoryUnit.adjust_units(order)
    end

    it "should restock units if a line item has an decreased in quantity"
  end

  context "sell_units" do
    let(:order) { mock_model(Order, :line_items => line_items, :inventory_units => mock('inventory-units'), :shipments => [shipment], :completed? => false) }

    it "should create correct number of inventory units for each variant" do
      (1..3).map do |n|
        order.inventory_units.should_receive(:create).with(:state => "sold", :variant => line_items[n-1].variant, :shipment => shipment).exactly(n).times
      end

      InventoryUnit.sell_units(order)
    end

    it "should not increase the number of inventory units if the order is completed" do
      order.stub!(:completed?).and_return(true)
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

