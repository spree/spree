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

  end
end
