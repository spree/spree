require 'spec_helper'

describe Spree::OrderInventory, :type => :model do
  let(:order) { create :completed_order_with_totals }
  let(:line_item) { order.line_items.first }

  subject { described_class.new(order, line_item) }

  context "when order is missing inventory units" do
    before { line_item.update_column(:quantity, 2) }

    it 'creates the proper number of inventory units' do
      subject.verify
      expect(subject.inventory_units.count).to eq 2
    end
  end

  context "#add_to_shipment" do
    let(:shipment) { order.shipments.first }

    context "order is not completed" do
      before { allow(order).to receive_messages completed?: false }

      it "doesn't unstock items" do
        expect(shipment.stock_location).not_to receive(:unstock)
        expect(subject.send(:add_to_shipment, shipment, 5)).to eq(5)
      end
    end

    context "inventory units state" do
      before { shipment.inventory_units.destroy_all }

      it 'sets inventory_units state as per stock location availability' do
        expect(shipment.stock_location).to receive(:fill_status).with(subject.variant, 5).and_return([3, 2])

        expect(subject.send(:add_to_shipment, shipment, 5)).to eq(5)

        units = shipment.inventory_units_for(subject.variant).group_by(&:state)
        expect(units['backordered'].size).to eq(2)
        expect(units['on_hand'].size).to eq(3)
      end
    end

    context "store doesnt track inventory" do
      let(:variant) { create(:variant) }

      before { Spree::Config.track_inventory_levels = false }

      it "creates only on hand inventory units" do
        variant.stock_items.destroy_all

        # The before_save callback in LineItem would verify inventory
        line_item = order.contents.add variant, 1, shipment: shipment

        units = shipment.inventory_units_for(line_item.variant)
        expect(units.count).to eq 1
        expect(units.first).to be_on_hand
      end
    end

    context "variant doesnt track inventory" do
      let(:variant) { create(:variant) }
      before { variant.track_inventory = false }

      it "creates only on hand inventory units" do
        variant.stock_items.destroy_all

        line_item = order.contents.add variant, 1
        subject.verify(shipment)

        units = shipment.inventory_units_for(line_item.variant)
        expect(units.count).to eq 1
        expect(units.first).to be_on_hand
      end
    end

    it 'should create stock_movement' do
      expect(subject.send(:add_to_shipment, shipment, 5)).to eq(5)

      stock_item = shipment.stock_location.stock_item(subject.variant)
      movement = stock_item.stock_movements.last
      # movement.originator.should == shipment
      expect(movement.quantity).to eq(-5)
    end
  end

  context "#determine_target_shipment" do
    let(:stock_location) { create :stock_location }
    let(:variant) { line_item.variant }

    before do
      subject.verify

      order.shipments.create(:stock_location_id => stock_location.id, :cost => 5)

      shipped = order.shipments.create(:stock_location_id => order.shipments.first.stock_location.id, :cost => 10)
      shipped.update_column(:state, 'shipped')
    end

    it 'should select first non-shipped shipment that already contains given variant' do
      shipment = subject.send(:determine_target_shipment)
      expect(shipment.shipped?).to be false
      expect(shipment.inventory_units_for(variant)).not_to be_empty

      expect(variant.stock_location_ids.include?(shipment.stock_location_id)).to be true
    end

    context "when no shipments already contain this varint" do
      before do
        subject.line_item.reload
        subject.inventory_units.destroy_all
      end

      it 'selects first non-shipped shipment that leaves from same stock_location' do
        shipment = subject.send(:determine_target_shipment)
        shipment.reload
        expect(shipment.shipped?).to be false
        expect(shipment.inventory_units_for(variant)).to be_empty
        expect(variant.stock_location_ids.include?(shipment.stock_location_id)).to be true
      end
    end
  end

  context 'when order has too many inventory units' do
    before do
      line_item.quantity = 3
      line_item.save!

      line_item.update_column(:quantity, 2)
      subject.line_item.reload
    end

    it 'should be a messed up order' do
      expect(order.shipments.first.inventory_units_for(line_item.variant).size).to eq(3)
      expect(line_item.quantity).to eq(2)
    end

    it 'should decrease the number of inventory units' do
      subject.verify
      expect(subject.inventory_units.count).to eq 2
    end

    context '#remove_from_shipment' do
      let(:shipment) { order.shipments.first }
      let(:variant) { subject.variant }

      context "order is not completed" do
        before { allow(order).to receive_messages completed?: false }

        it "doesn't restock items" do
          expect(shipment.stock_location).not_to receive(:restock)
          expect(subject.send(:remove_from_shipment, shipment, 1)).to eq(1)
        end
      end

      it 'should create stock_movement' do
        expect(subject.send(:remove_from_shipment, shipment, 1)).to eq(1)

        stock_item = shipment.stock_location.stock_item(variant)
        movement = stock_item.stock_movements.last
        # movement.originator.should == shipment
        expect(movement.quantity).to eq(1)
      end

      it 'should destroy backordered units first' do
        allow(shipment).to receive_messages(inventory_units_for_item: [
          mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'backordered'),
          mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'on_hand'),
          mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'backordered')
        ])

        expect(shipment.inventory_units_for_item[0]).to receive(:destroy)
        expect(shipment.inventory_units_for_item[1]).not_to receive(:destroy)
        expect(shipment.inventory_units_for_item[2]).to receive(:destroy)

        expect(subject.send(:remove_from_shipment, shipment, 2)).to eq(2)
      end

      it 'should destroy unshipped units first' do
        allow(shipment).to receive_messages(inventory_units_for_item: [
          mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'shipped'),
          mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'on_hand')
        ])

        expect(shipment.inventory_units_for_item[0]).not_to receive(:destroy)
        expect(shipment.inventory_units_for_item[1]).to receive(:destroy)

        expect(subject.send(:remove_from_shipment, shipment, 1)).to eq(1)
      end

      it 'only attempts to destroy as many units as are eligible, and return amount destroyed' do
        allow(shipment).to receive_messages(inventory_units_for_item: [
          mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'shipped'),
          mock_model(Spree::InventoryUnit, :variant_id => variant.id, :state => 'on_hand')
        ])

        expect(shipment.inventory_units_for_item[0]).not_to receive(:destroy)
        expect(shipment.inventory_units_for_item[1]).to receive(:destroy)

        expect(subject.send(:remove_from_shipment, shipment, 1)).to eq(1)
      end

      it 'should destroy self if not inventory units remain' do
        allow(shipment.inventory_units).to receive_messages(:count => 0)
        expect(shipment).to receive(:destroy)

        expect(subject.send(:remove_from_shipment, shipment, 1)).to eq(1)
      end

      context "inventory unit line item and variant points to different products" do
        let(:different_line_item) { create(:line_item) }

        let!(:different_inventory) do
          shipment.set_up_inventory("on_hand", variant, order, different_line_item)
        end

        context "completed order" do
          before { order.touch :completed_at }

          it "removes only units that match both line item and variant" do
            subject.send(:remove_from_shipment, shipment, shipment.inventory_units.count)
            expect(different_inventory.reload).to be_persisted
          end
        end
      end
    end
  end
end
