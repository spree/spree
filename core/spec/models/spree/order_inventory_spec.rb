require 'spec_helper'

describe Spree::OrderInventory do
  let(:order) { create :completed_order_with_totals }
  let(:line_item) { order.line_items.first }
  subject { described_class.new(order) }

  context 'when order is missing inventory units' do

    before do
      line_item.update_attribute_without_callbacks(:quantity, 2)
    end

    it 'should be a messed up order' do
      order.shipment.inventory_units_for(line_item.variant).size.should == 1
      line_item.reload.quantity.should == 2
    end

    it 'should increase the number of inventory units' do
      subject.verify(line_item)
      order.reload.shipment.inventory_units_for(line_item.variant).size.should == 2
    end

    context "#add_to_shipment" do
      let(:shipment) { order.shipments.first }
      let(:variant) { create :variant }

      it 'should create inventory_units in the necessary states' do
        shipment.stock_location.should_receive(:fill_status).with(variant, 5).and_return([3, 2])

        subject.send(:add_to_shipment, shipment, variant, 5).should == 5

        units = shipment.inventory_units.group_by &:variant_id
        units = units[variant.id].group_by &:state
        units['backordered'].size.should == 2
        units['on_hand'].size.should == 3
      end

      it 'should create stock_movement' do
        subject.send(:add_to_shipment, shipment, variant, 5).should == 5

        stock_item = shipment.stock_location.stock_item(variant)
        movement = stock_item.stock_movements.last
        # movement.originator.should == shipment
        movement.quantity.should == -5
      end
    end
  end

  context 'when order has too many inventory units' do
    before do
      line_item.quantity = 3
      line_item.save!

      line_item.update_attribute_without_callbacks(:quantity, 2)
      order.reload
    end

    it 'should be a messed up order' do
      order.shipment.inventory_units_for(line_item.variant).size.should == 3
      line_item.quantity.should == 2
    end

    it 'should decrease the number of inventory units' do
      subject.verify(line_item)
      order.reload.shipment.inventory_units_for(line_item.variant).size.should == 2
    end

    context '#remove_from_shipment' do
      let(:shipment) { order.shipments.first }
      let(:variant) { order.line_items.first.variant }

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

      it 'should only attempt to destroy as many units as are eligible, and return amount destroyed' do
        shipment.stub(:inventory_units_for => [ mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'shipped'),
                                                mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'on_hand') ] )

        shipment.inventory_units_for[0].should_not_receive(:destroy)
        shipment.inventory_units_for[1].should_receive(:destroy)

        subject.send(:remove_from_shipment, shipment, variant, 3).should == 1
      end

      xit 'should raise exception if not enough deletable units are present' do
        expect {
          order.contents.add(variant, 2)
          shipment.stub(:inventory_units => [ mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'shipped'),
                                              mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'shipped') ] )

          subject.send(:remove_from_shipment, shipment, variant, 1).should == 1

        }.to raise_error(/Shipment does not contain enough deletable inventory_units/)
      end

      xit 'should raise exception if variant does not belong to shipment' do
        expect {
          order.contents.add(variant, 2)
          shipment.stub(:inventory_units => [ mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'shipped'),
                                              mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'shipped') ] )

          subject.send(:remove_from_shipment, shipment, variant, 1).should == 1

        }.to raise_error(/Variant does not belong to this shipment/)
      end

      it 'should destroy self if not inventory units remain' do
        shipment.inventory_units.stub(:count => 0)
        shipment.should_receive(:destroy)

        subject.send(:remove_from_shipment, shipment, variant, 1).should == 1
      end
    end

  end
end
