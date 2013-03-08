require 'spec_helper'

describe Spree::InventoryUnit do
  let(:variant) { mock_model(Spree::Variant) }
  let(:line_item) { mock_model(Spree::LineItem, variant: variant, quantity: 5) }
  let(:order) { mock_model(Spree::Order, line_items: [line_item],
    inventory_units: [], shipments: mock('shipments'), completed?: true) }
  let(:stock_location) { create(:stock_location_with_items) }
  let(:stock_item) { stock_location.stock_items.first }

  context "#backordered_for_stock_item" do
    let(:order) { create(:order) }
    let(:shipment) do
      shipping_method = create(:shipping_method)
      shipment = Spree::Shipment.new
      shipment.stock_location = stock_location
      shipment.shipping_methods << shipping_method
      shipment.order = order
      # We don't care about this in this test
      shipment.stub(:ensure_correct_adjustment)
      shipment.tap(&:save!)
    end

    let!(:unit) do
      unit = shipment.inventory_units.build
      unit.state = 'backordered'
      unit.variant_id = 1
      unit.tap(&:save!)
    end

    it "finds inventory units from its stock location when the unit's variant matches the stock item's variant" do
      stock_item.variant_id = 1
      Spree::InventoryUnit.backordered_for_stock_item(stock_item).should =~ [unit]
    end

    it "does not find inventory units that aren't backordered" do
      on_hand_unit = shipment.inventory_units.build
      on_hand_unit.state = 'on_hand'
      on_hand_unit.tap(&:save!)

      Spree::InventoryUnit.backordered_for_stock_item(stock_item).should_not include(on_hand_unit)
    end

    it "does not find inventory units that don't match the stock item's variant" do
      other_variant_unit = shipment.inventory_units.build
      other_variant_unit.state = 'backordered'
      other_variant_unit.variant = create(:variant)
      other_variant_unit.tap(&:save!)

      Spree::InventoryUnit.backordered_for_stock_item(stock_item).should_not include(other_variant_unit)
    end
  end

  context "#finalize_units!" do
    let!(:stock_location) { create(:stock_location) }
    let(:variant) { create(:variant) }
    let(:inventory_units) { [
      create(:inventory_unit, variant: variant),
      create(:inventory_unit, variant: variant)
    ] }

    it "should create a stock movement" do
      Spree::InventoryUnit.finalize_units!(inventory_units)
      inventory_units.any?(&:pending).should be_false
    end
  end

  context "#finalize!" do
    let(:inventory_unit) { FactoryGirl.create(:inventory_unit)  }
    
    it "should mark the shipment not pending" do
      inventory_unit.stub(:stock_item, FactoryGirl.create(:stock_item))
      inventory_unit.pending.should == true
      inventory_unit.finalize!
      inventory_unit.pending.should == false
    end

    it "should create a stock movement" do
      inventory_unit.stub(:stock_item, FactoryGirl.create(:stock_item))
      expect {inventory_unit.finalize!}.to change{Spree::StockMovement.count}.by(1)

    end
  end
end


