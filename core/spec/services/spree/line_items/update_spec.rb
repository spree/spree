require 'spec_helper'

module Spree
  describe LineItems::Update do
    subject { described_class }

    let(:order) { create :order, line_items: [line_item] }
    let!(:line_item) { create :line_item, variant: variant, price: nil, quantity: 10 }
    let(:variant) { create :variant, price: 20 }
    let(:execute) { subject.call(line_item: line_item, line_item_attributes: line_item_attributes) }
    let(:value) { execute.value }
    let(:line_item_attributes) { { quantity: 11 } }

    context 'updates line item' do
      it 'with any quantity' do
        expect(order.amount).to eq(200)
        expect(order.quantity).to eq(10)
        expect { execute }.to change(order, :quantity).by(1)
        expect(order.item_count).to eq(11)
        expect(execute).to be_success
        expect(value).to eq line_item
      end
    end

    context 'given a shipment' do
      let(:shipment) { create :shipment }
      let(:options) { { shipment: shipment } }
      let(:execute) { subject.call(line_item: line_item, line_item_attributes: line_item_attributes, options: options) }

      it 'ensure shipment calls update_amounts instead of order calling ensure_updated_shipments' do
        expect(order).not_to receive(:ensure_updated_shipments)
        expect(shipment).to receive(:update_amounts)
        expect(execute).to be_success
      end
    end

    context 'not given a shipment' do
      let(:execute) { subject.call(line_item: line_item, line_item_attributes: line_item_attributes) }

      it 'ensures updated shipments' do
        expect(order).to receive(:ensure_updated_shipments)
        expect(execute).to be_success
      end
    end
  end
end
