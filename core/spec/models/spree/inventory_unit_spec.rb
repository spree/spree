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
      unit.tap(&:save!)
    end

    it "finds inventory units from its stock location" do
      Spree::InventoryUnit.backordered_for_stock_item(stock_item).should =~ [unit]
    end

    context "does not find inventory units from other stock locations" do
      before do
        stock_item.stock_location = create(:stock_location)
        stock_item.save!
      end

      specify do
        Spree::InventoryUnit.backordered_for_stock_item(stock_item).should be_empty
      end
    end
  end

  context "#increase" do
    context "when :track_inventory_levels is true" do
      before do
        Spree::Config.set :track_inventory_levels => true
        Spree::InventoryUnit.stub(:create_units)
      end

      it "should create a new stock movement" do
        lambda {
          Spree::InventoryUnit.increase(order, stock_item, 5)
        }.should change(Spree::StockMovement, :count).by(1)
      end

    end

    context "when :track_inventory_levels is false" do
      before do
        Spree::Config.set :track_inventory_levels => false
        Spree::InventoryUnit.stub(:create_units)
      end

      it "should not create a new stock movement" do
        lambda {
          Spree::InventoryUnit.increase(order, stock_item, 5)
        }.should_not change(Spree::StockMovement, :count)
      end

    end

    context "when :create_inventory_units is true" do
      before do
        Spree::Config.set :create_inventory_units => true
        variant.stub(:decrement!)
      end

      it "should create units" do
        Spree::InventoryUnit.should_receive(:create_units)
        Spree::InventoryUnit.increase(order, stock_item, 5)
      end

    end

    context "when :create_inventory_units is false" do
      before do
        Spree::Config.set :create_inventory_units => false
        variant.stub(:decrement!)
      end

      it "should not create units" do
        Spree::InventoryUnit.should_not_receive(:create_units)
        Spree::InventoryUnit.increase(order, stock_item, 5)
      end

    end

  end

  context "#decrease" do
    context "when :track_inventory_levels is true" do
      before do
        Spree::Config.set :track_inventory_levels => true
        Spree::InventoryUnit.stub(:destroy_units)
      end

      it "should create a new stock movement" do
        lambda {
          Spree::InventoryUnit.decrease(order, stock_item, 5)
        }.should change(Spree::StockMovement, :count).by(1)
      end

    end

    context "when :track_inventory_levels is false" do
      before do
        Spree::Config.set :track_inventory_levels => false
        Spree::InventoryUnit.stub(:destroy_units)
      end

      it "should not create a new stock movement" do
        lambda {
          Spree::InventoryUnit.decrease(order, stock_item, 5)
        }.should_not change(Spree::StockMovement, :count)
      end

    end

    context "when :create_inventory_units is true" do
      before do
        Spree::Config.set :create_inventory_units => true
        variant.stub(:increment!)
      end

      it "should destroy units" do
        stock_item.stub(:variant => variant)
        Spree::InventoryUnit.should_receive(:destroy_units).with(order, variant, 5)
        Spree::InventoryUnit.decrease(order, stock_item, 5)
      end

    end

    context "when :create_inventory_units is false" do
      before do
        Spree::Config.set :create_inventory_units => false
        variant.stub(:increment!)
      end

      it "should destroy units" do
        Spree::InventoryUnit.should_not_receive(:destroy_units)
        Spree::InventoryUnit.decrease(order, stock_item, 5)
      end

    end

  end

  context "#determine_backorder" do
    context "when :track_inventory_levels is true" do
      before { Spree::Config.set :create_inventory_units => true }

      context "and all units are in stock" do
        it "should return zero back orders" do
          Spree::InventoryUnit.determine_backorder(order, stock_item, 5).should == 0
        end
      end

      context "and partial units are in stock" do
        before { stock_item.stub(:count_on_hand).and_return(2) }

        it "should return correct back order amount" do
          Spree::InventoryUnit.determine_backorder(order, stock_item, 5).should == 3
        end
      end

      context "and zero units are in stock" do
        before { stock_item.stub(:count_on_hand).and_return(0) }

        it "should return correct back order amount" do
          Spree::InventoryUnit.determine_backorder(order, stock_item, 5).should == 5
        end
      end

      context "and less than zero units are in stock" do
        before { stock_item.stub(:count_on_hand).and_return(-9) }

        it "should return entire amount as back order" do
          Spree::InventoryUnit.determine_backorder(order, stock_item, 5).should == 5
        end
      end
    end

    context "when :track_inventory_levels is false" do
      before { Spree::Config.set :track_inventory_levels => false }

      it "should return zero back orders" do
        stock_item.stub(:count_on_hand).and_return(nil)
        Spree::InventoryUnit.determine_backorder(order, stock_item, 5).should == 0
      end
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

    # Regression test for #2074
    context "with inventory tracking disabled" do
      before { Spree::Config[:track_inventory_levels] = false }

      it "does not update on_hand for variant" do
        inventory_unit.variant.should_not_receive(:on_hand=).with(96)
        inventory_unit.variant.should_not_receive(:save)
        inventory_unit.return!
      end
    end
  end

  context "#finalize!" do
    let(:inventory_unit) { FactoryGirl.create(:inventory_unit)  }

    it "should mark the shipment not pending" do
      Spree::StockMovement.should_receive(:create!).with(hash_including(:quantity => 1, :action => 'sold'))

      inventory_unit.pending.should == true
      inventory_unit.finalize!
      inventory_unit.pending.should == false
    end

    it "should create a stock movement" do
      Spree::StockMovement.should_receive(:create!).with(hash_including(:quantity => 1, :action => 'sold'))
      inventory_unit.finalize!
    end
  end
end

