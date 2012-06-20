require 'spec_helper'

describe Spree::InventoryUnit do
  before(:each) do
    reset_spree_preferences
  end

  let(:variant) { mock_model(Spree::Variant, :on_hand => 95) }
  let(:line_item) { mock_model(Spree::LineItem, :variant => variant, :quantity => 5) }
  let(:order) { mock_model(Spree::Order, :line_items => [line_item], :inventory_units => [], :shipments => mock('shipments'), :completed? => true) }

  context "#assign_opening_inventory" do
    context "when order is complete" do

      it "should increase inventory" do
        Spree::InventoryUnit.should_receive(:increase).with(order, variant, 5).and_return([])
        Spree::InventoryUnit.assign_opening_inventory(order)
      end

    end

    context "when order is not complete" do
      before { order.stub(:completed?).and_return(false) }

      it "should not do anything" do
        Spree::InventoryUnit.should_not_receive(:increase)
        Spree::InventoryUnit.assign_opening_inventory(order).should == []
      end

    end
  end

  context "#increase" do
    context "when :track_inventory_levels is true" do
      before do
        Spree::Config.set :track_inventory_levels => true
        Spree::InventoryUnit.stub(:create_units)
      end

      it "should decrement count_on_hand" do
        variant.should_receive(:decrement!).with(:count_on_hand, 5)
        Spree::InventoryUnit.increase(order, variant, 5)
      end

    end

    context "when :track_inventory_levels is false" do
      before do
        Spree::Config.set :track_inventory_levels => false
        Spree::InventoryUnit.stub(:create_units)
      end

      it "should decrement count_on_hand" do
        pending
        variant.should_not_receive(:decrement!)
        Spree::InventoryUnit.increase(order, variant, 5)
      end

    end

    context "when :create_inventory_units is true" do
      before do
        Spree::Config.set :create_inventory_units => true
        variant.stub(:decrement!)
      end

      it "should create units" do
        Spree::InventoryUnit.should_receive(:create_units)
        Spree::InventoryUnit.increase(order, variant, 5)
      end

    end

    context "when :create_inventory_units is false" do
      before do
        Spree::Config.set :create_inventory_units => false
        variant.stub(:decrement!)
      end

      it "should not create units" do
        pending
        Spree::InventoryUnit.should_not_receive(:create_units)
        Spree::InventoryUnit.increase(order, variant, 5)
      end

    end

  end

  context "#decrease" do
    context "when :track_inventory_levels is true" do
      before do
        Spree::Config.set :track_inventory_levels => true
        Spree::InventoryUnit.stub(:destroy_units)
      end

      it "should decrement count_on_hand" do
        variant.should_receive(:increment!).with(:count_on_hand, 5)
        Spree::InventoryUnit.decrease(order, variant, 5)
      end

    end

    context "when :track_inventory_levels is false" do
      before do
        Spree::Config.set :track_inventory_levels => false
        Spree::InventoryUnit.stub(:destroy_units)
      end

      it "should decrement count_on_hand" do
        pending
        variant.should_not_receive(:increment!)
        Spree::InventoryUnit.decrease(order, variant, 5)
      end

    end

    context "when :create_inventory_units is true" do
      before do
        Spree::Config.set :create_inventory_units => true
        variant.stub(:increment!)
      end

      it "should destroy units" do
        Spree::InventoryUnit.should_receive(:destroy_units).with(order, variant, 5)
        Spree::InventoryUnit.decrease(order, variant, 5)
      end

    end

    context "when :create_inventory_units is false" do
      before do
        Spree::Config.set :create_inventory_units => false
        variant.stub(:increment!)
      end

      it "should destroy units" do
        pending
        Spree::InventoryUnit.should_not_receive(:destroy_units)
        Spree::InventoryUnit.decrease(order, variant, 5)
      end

    end

  end

  context "#determine_backorder" do
    context "when :track_inventory_levels is true" do
      before { Spree::Config.set :create_inventory_units => true }

      context "and all units are in stock" do
        it "should return zero back orders" do
          Spree::InventoryUnit.determine_backorder(order, variant, 5).should == 0
        end
      end

      context "and partial units are in stock" do
        before { variant.stub(:on_hand).and_return(2) }

        it "should return correct back order amount" do
          Spree::InventoryUnit.determine_backorder(order, variant, 5).should == 3
        end
      end

      context "and zero units are in stock" do
        before { variant.stub(:on_hand).and_return(0) }

        it "should return correct back order amount" do
          Spree::InventoryUnit.determine_backorder(order, variant, 5).should == 5
        end
      end

      context "and less than zero units are in stock" do
        before { variant.stub(:on_hand).and_return(-9) }

        it "should return entire amount as back order" do
          Spree::InventoryUnit.determine_backorder(order, variant, 5).should == 5
        end
      end
    end

    context "when :track_inventory_levels is false" do
      before { Spree::Config.set :track_inventory_levels => false }

      it "should return zero back orders" do
        variant.stub(:on_hand).and_return(nil)
        Spree::InventoryUnit.determine_backorder(order, variant, 5).should == 0
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
  end
end

