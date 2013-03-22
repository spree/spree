require 'spec_helper'

describe Spree::InventoryUnit do
  let(:variant) { mock_model(Spree::Variant) }
  let(:line_item) { mock_model(Spree::LineItem, :variant => variant, :quantity => 5) }
  let(:order) { mock_model(Spree::Order, :line_items => [line_item], :inventory_units => [], :shipments => mock('shipments'), :completed? => true) }
  let(:stock_location) { create(:stock_location_with_items) }
  let(:stock_item) { stock_location.stock_items.first }

  context "#backordered_inventory_units" do
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

  context "#create_units" do
    let(:shipment) { mock_model(Spree::Shipment) }
    before { order.shipments.stub :detect => shipment }

    context "when :allow_backorders is true" do
      before { Spree::Config.set :allow_backorders => true }

      it "should create both sold and backordered units" do
        order.inventory_units.should_receive(:create).with({:variant => variant, :state => "sold", :shipment => shipment}, :without_protection => true).exactly(2).times
        order.inventory_units.should_receive(:create).with({:variant => variant, :state => "backordered", :shipment => shipment}, :without_protection => true).exactly(3).times
        Spree::InventoryUnit.create_units(order, variant, 2, 3)
      end

    end

    context "when :allow_backorders is false" do
      before { Spree::Config.set :allow_backorders => false }

      it "should create sold items" do
        order.inventory_units.should_receive(:create).with({:variant => variant, :state => "sold", :shipment => shipment}, :without_protection => true).exactly(2).times
        Spree::InventoryUnit.create_units(order, variant, 2, 0)
      end

    end

  end

  context "#destroy_units" do
    before { order.stub(:inventory_units => [mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => "sold")]) }

    it "should call destroy correct number of units" do
      order.inventory_units.each { |unit| unit.should_receive(:destroy) }
      Spree::InventoryUnit.destroy_units(order, variant, 1)
    end

    context "when inventory_units contains backorders" do
      before { order.stub(:inventory_units => [ mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'backordered'),
                                                mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'sold'),
                                                mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'backordered') ]) }

      it "should destroy backordered units first" do
        order.inventory_units[0].should_receive(:destroy)
        order.inventory_units[1].should_not_receive(:destroy)
        order.inventory_units[2].should_receive(:destroy)
        Spree::InventoryUnit.destroy_units(order, variant, 2)
      end
    end

    context "when inventory_units contains sold and shipped" do
      before { order.stub(:inventory_units => [ mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'shipped'),
                                                mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'sold') ]) }
      # Regression test for #1652
      it "should not destroy shipped" do
        order.inventory_units[0].should_not_receive(:destroy)
        order.inventory_units[1].should_receive(:destroy)
        Spree::InventoryUnit.destroy_units(order, variant, 1)
      end
    end
  end

  context "return!" do
    let(:inventory_unit) { Spree::InventoryUnit.create({:state => "shipped", :variant => mock_model(Spree::Variant, :on_hand => 95)}, :without_protection => true) }

    it "should update on_hand for variant" do
      inventory_unit.variant.should_receive(:on_hand=).with(96)
      inventory_unit.variant.should_receive(:save)
      inventory_unit.return!
    end
  end

  context "finalize_units!" do
    let!(:stock_location) { create(:stock_location) }
    let(:variant) { create(:variant) }
    let(:inventory_units) { [create(:inventory_unit, :variant => variant), create(:inventory_unit, :variant => variant)] }

    # it "should create a stock movement" do
    #   Spree::StockMovement.should_receive(:create!).with(hash_including(:quantity => -2))
    #   Spree::InventoryUnit.finalize_units!(inventory_units)
    #   inventory_units.any?(&:pending).should be_false
    # end
  end
end

