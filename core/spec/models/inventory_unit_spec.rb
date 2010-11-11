require 'spec_helper'

describe InventoryUnit do
  let(:variant) { mock_model(Variant, :on_hand => 95) }
  let(:line_item) { mock_model(LineItem, :variant => variant, :quantity => 5) }
  let(:order) { mock_model(Order, :line_items => [line_item], :inventory_units => [], :shipments => mock('shipments'), :completed? => true) }

  context "#assign_opening_inventory" do
    context "when order is complete" do

      it "should increase inventory" do
        InventoryUnit.should_receive(:increase).with(order, variant, 5).and_return([])
        InventoryUnit.assign_opening_inventory(order)
      end

    end

    context "when order is not complete" do
      before { order.stub(:completed?).and_return(false) }

      it "should not do anything" do
        InventoryUnit.should_not_receive(:increase)
        InventoryUnit.assign_opening_inventory(order).should == []
      end

    end
  end

  context "#increase" do
    context "when :track_inventory_levels is true" do
      before do
        Spree::Config.set :track_inventory_levels => true
        InventoryUnit.stub(:create_units)
      end

      it "should decrement count_on_hand" do
        variant.should_receive(:decrement!).with(:count_on_hand, 5)
        InventoryUnit.increase(order, variant, 5)
      end

    end

    context "when :track_inventory_levels is false" do
      before do
        Spree::Config.set :track_inventory_levels => false
        InventoryUnit.stub(:create_units)
      end

      it "should decrement count_on_hand" do
        variant.should_not_receive(:decrement!)
        InventoryUnit.increase(order, variant, 5)
      end

      context "and :create_inventory_units is true" do
        before { Spree::Config.set :create_inventory_units => true }
        let(:variant) { stub_model(Variant, :count_on_hand => 95) }

        it "should create units as sold regardless of count_on_hand value " do
          InventoryUnit.should_receive(:create_units).with(order, variant, 5, 0)
          InventoryUnit.increase(order, variant, 5)
        end
      end
    end

    context "when :create_inventory_units is true" do
      before do
        Spree::Config.set :create_inventory_units => true
        variant.stub(:decrement!)
      end

      context "and all units are in stock" do
        it "should create units as sold" do
          InventoryUnit.should_receive(:create_units).with(order, variant, 5, 0)
          InventoryUnit.increase(order, variant, 5)
        end
      end

      context "and partial units are in stock" do
        before { variant.stub(:on_hand).and_return(2) }

        it "should create units as sold and backordered" do
          InventoryUnit.should_receive(:create_units).with(order, variant, 2, 3)
          InventoryUnit.increase(order, variant, 5)
        end
      end

      context "and zero units are in stock" do
        before { variant.stub(:on_hand).and_return(0) }

        it "should create units as backordered" do
          InventoryUnit.should_receive(:create_units).with(order, variant, 0, 5)
          InventoryUnit.increase(order, variant, 5)
        end
      end

      context "and less than zero units are in stock" do
        before { variant.stub(:on_hand).and_return(-9) }

        it "should create units as backordered" do
          InventoryUnit.should_receive(:create_units).with(order, variant, 0, 5)
          InventoryUnit.increase(order, variant, 5)
        end
      end


    end

    context "when :create_inventory_units is false" do
      before do
        Spree::Config.set :create_inventory_units => false
        variant.stub(:decrement!)
      end

      it "should not create units" do
        InventoryUnit.should_not_receive(:create_units)
        InventoryUnit.increase(order, variant, 5)
      end

    end

  end

  context "#decrease" do
    context "when :track_inventory_levels is true" do
      before do
        Spree::Config.set :track_inventory_levels => true
        InventoryUnit.stub(:destroy_units)
      end

      it "should decrement count_on_hand" do
        variant.should_receive(:increment!).with(:count_on_hand, 5)
        InventoryUnit.decrease(order, variant, 5)
      end

    end

    context "when :track_inventory_levels is false" do
      before do
        Spree::Config.set :track_inventory_levels => false
        InventoryUnit.stub(:destroy_units)
      end

      it "should decrement count_on_hand" do
        variant.should_not_receive(:increment!)
        InventoryUnit.decrease(order, variant, 5)
      end

    end

    context "when :create_inventory_units is true" do
      before do
        Spree::Config.set :create_inventory_units => true
        variant.stub(:increment!)
      end

      it "should destroy units" do
        InventoryUnit.should_receive(:destroy_units).with(order, variant, 5)
        InventoryUnit.decrease(order, variant, 5)
      end

    end

    context "when :create_inventory_units is false" do
      before do
        Spree::Config.set :create_inventory_units => false
        variant.stub(:increment!)
      end

      it "should destroy units" do
        InventoryUnit.should_not_receive(:destroy_units)
        InventoryUnit.decrease(order, variant, 5)
      end

    end

  end

  context "#create_units" do
    let(:shipment) { mock_model(Shipment) }
    before { order.stub_chain(:shipments, :detect => shipment) }

    context "when :allow_backorders is true" do
      before { Spree::Config.set :allow_backorders => true }

      it "should create both sold and backordered units" do
        order.inventory_units.should_receive(:create).with(:variant => variant, :state => "sold", :shipment => shipment).exactly(2).times
        order.inventory_units.should_receive(:create).with(:variant => variant, :state => "backordered", :shipment => shipment).exactly(3).times
        InventoryUnit.create_units(order, variant, 2, 3)
      end

      it "should return hash of backorders items" do
        order.inventory_units.should_receive(:create).exactly(5).times
        InventoryUnit.create_units(order, variant, 2, 3).should == [{:variant => variant, :count => 3}]
      end

    end

    context "when :allow_backorders is false" do
      before { Spree::Config.set :allow_backorders => false }

      it "should create sold units and not backordered units" do
        order.inventory_units.should_receive(:create).with(:variant => variant, :state => "sold", :shipment => shipment).exactly(2).times
        order.inventory_units.should_not_receive(:create).with(:variant => variant, :state => "backordered", :shipment => shipment)
        InventoryUnit.create_units(order, variant, 2, 3)
      end

      it "should return hash of backorders items" do
        order.inventory_units.should_receive(:create).exactly(2).times
        InventoryUnit.create_units(order, variant, 2, 3).should == [{:variant => variant, :count => 3}]
      end

    end

  end

  context "#destroy_units" do
    before { order.stub(:inventory_units => [mock_model(InventoryUnit, :variant_id => variant.id, :state => "sold")]) }

    it "should call destroy correct number of units" do
      order.inventory_units.each { |unit| unit.should_receive(:destroy) }
      InventoryUnit.destroy_units(order, variant, 1)
    end

    context "when inventory_units contains backorders" do
      before { order.stub(:inventory_units => [ mock_model(InventoryUnit, :variant_id => variant.id, :state => 'backordered'),
                                                mock_model(InventoryUnit, :variant_id => variant.id, :state => 'sold'),
                                                mock_model(InventoryUnit, :variant_id => variant.id, :state => 'backordered') ]) }

      it "should destroy backordered units first" do
        order.inventory_units[0].should_receive(:destroy)
        order.inventory_units[1].should_not_receive(:destroy)
        order.inventory_units[2].should_receive(:destroy)
        InventoryUnit.destroy_units(order, variant, 2)
      end
    end

  end

  context "return!" do
    let(:inventory_unit) { InventoryUnit.create(:state => "shipped", :variant => mock_model(Variant, :on_hand => 95)) }

    it "should update on_hand for variant" do
      inventory_unit.variant.should_receive(:on_hand=).with(96)
      inventory_unit.variant.should_receive(:save)
      inventory_unit.return!
    end
  end
end

