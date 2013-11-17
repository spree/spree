require 'spec_helper'

describe Spree::OrderInventory do
  let(:order) { create :completed_order_with_totals }
  let(:line_item) { order.line_items.first }
  subject { described_class.new(order) }

  it 'inventory_units_for should return array of units for a given variant' do
    units = subject.inventory_units_for(line_item.variant)
    units.map(&:variant_id).should == [line_item.variant.id]
  end

  context "when order is missing inventory units" do
    before do
      line_item.update_column(:quantity, 2)
    end

    it 'should be a messed up order' do
      order.shipments.first.inventory_units_for(line_item.variant).size.should == 1
      line_item.reload.quantity.should == 2
    end

    it 'should increase the number of inventory units' do
      subject.verify(line_item)
      order.reload.shipments.first.inventory_units_for(line_item.variant).size.should == 2
    end
  end

  context "#add_to_shipment" do
    let(:shipment) { order.shipments.first }
    let(:variant) { create :variant }

    context "order is not completed" do
      before { order.stub completed?: false }

      it "doesn't unstock items" do
        shipment.stock_location.should_not_receive(:unstock)
        subject.send(:add_to_shipment, shipment, variant, 5).should == 5
      end
    end

    it 'should create inventory_units in the necessary states' do
      shipment.stock_location.should_receive(:fill_status).with(variant, 5).and_return([3, 2])

      subject.send(:add_to_shipment, shipment, variant, 5).should == 5

      units = shipment.inventory_units.group_by &:variant_id
      units = units[variant.id].group_by &:state
      units['backordered'].size.should == 2
      units['on_hand'].size.should == 3
    end

    context "store doesnt track inventory" do
      before { Spree::Config.track_inventory_levels = false }

      it "creates only on hand inventory units" do
        variant.stock_items.destroy_all

        line_item = order.contents.add variant, 1
        subject.verify(line_item, shipment)

        units = shipment.inventory_units_for(line_item.variant)
        expect(units.count).to eq 1
        expect(units.first).to be_on_hand
      end
    end

    context "variant doesnt track inventory" do
      before { variant.track_inventory = false }

      it "creates only on hand inventory units" do
        variant.stock_items.destroy_all

        line_item = order.contents.add variant, 1
        subject.verify(line_item, shipment)

        units = shipment.inventory_units_for(line_item.variant)
        expect(units.count).to eq 1
        expect(units.first).to be_on_hand
      end
    end

    it 'should create stock_movement' do
      subject.send(:add_to_shipment, shipment, variant, 5).should == 5

      stock_item = shipment.stock_location.stock_item(variant)
      movement = stock_item.stock_movements.last
      # movement.originator.should == shipment
      movement.quantity.should == -5
    end
  end

  context "#determine_target_shipment" do
    let(:stock_location) { create :stock_location }
    let(:variant) { line_item.variant }

    before do
      order.shipments.create(:stock_location_id => stock_location.id)
      shipped = order.shipments.create(:stock_location_id => order.shipments.first.stock_location.id)
      shipped.update_column(:state, 'shipped')
    end

    it 'should select first non-shipped shipment that already contains given variant' do
      shipment = subject.send(:determine_target_shipment, variant)
      shipment.shipped?.should be_false
      shipment.inventory_units_for(variant).should_not be_empty
      variant.stock_location_ids.include?(shipment.stock_location_id).should be_true
    end

    context "when no shipments already contain this varint" do
      it 'selects first non-shipped shipment that leaves from same stock_location' do
        subject.send(:remove_from_shipment, order.shipments.first, variant, line_item.quantity)

        shipment = subject.send(:determine_target_shipment, variant)
        shipment.reload
        shipment.shipped?.should be_false
        shipment.inventory_units_for(variant).should be_empty
        variant.stock_location_ids.include?(shipment.stock_location_id).should be_true
      end
    end
  end

  context 'when order has too many inventory units' do
    before do
      line_item.quantity = 3
      line_item.save!

      line_item.update_column(:quantity, 2)
      order.reload
    end

    it 'should be a messed up order' do
      order.shipments.first.inventory_units_for(line_item.variant).size.should == 3
      line_item.quantity.should == 2
    end

    it 'should decrease the number of inventory units' do
      subject.verify(line_item)
      order.reload.shipments.first.inventory_units_for(line_item.variant).size.should == 2
    end

    context '#remove_from_shipment' do
      let(:shipment) { order.shipments.first }
      let(:variant) { order.line_items.first.variant }

      context "order is not completed" do
        before { order.stub completed?: false }

        it "doesn't restock items" do
          shipment.stock_location.should_not_receive(:restock)
          subject.send(:remove_from_shipment, shipment, variant, 1).should == 1
        end
      end

      it 'should create stock_movement' do
        subject.send(:remove_from_shipment, shipment, variant, 1).should == 1

        stock_item = shipment.stock_location.stock_item(variant)
        movement = stock_item.stock_movements.last
        # movement.originator.should == shipment
        movement.quantity.should == 1
      end

      it 'should destroy backordered units first' do
        shipment.stub(:inventory_units_for => [ mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'backordered'),
                                                mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'on_hand'),
                                                mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'backordered') ])

        shipment.inventory_units_for[0].should_receive(:destroy)
        shipment.inventory_units_for[1].should_not_receive(:destroy)
        shipment.inventory_units_for[2].should_receive(:destroy)

        subject.send(:remove_from_shipment, shipment, variant, 2).should == 2
      end

      it 'should destroy unshipped units first' do
        shipment.stub(:inventory_units_for => [ mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'shipped'),
                                                mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'on_hand') ] )

        shipment.inventory_units_for[0].should_not_receive(:destroy)
        shipment.inventory_units_for[1].should_receive(:destroy)

        subject.send(:remove_from_shipment, shipment, variant, 1).should == 1
      end

      it 'only attempts to destroy as many units as are eligible, and return amount destroyed' do
        shipment.stub(:inventory_units_for => [ mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'shipped'),
                                                mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'on_hand') ] )

        shipment.inventory_units_for[0].should_not_receive(:destroy)
        shipment.inventory_units_for[1].should_receive(:destroy)

        subject.send(:remove_from_shipment, shipment, variant, 1).should == 1
      end

      it 'should destroy self if not inventory units remain' do
        shipment.inventory_units.stub(:count => 0)
        shipment.should_receive(:destroy)

        subject.send(:remove_from_shipment, shipment, variant, 1).should == 1
      end
    end
  end
end
