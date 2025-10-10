require 'spec_helper'

module Spree
  describe Cart::RemoveLineItem do
    subject { described_class }

    let(:order) { create :order, line_items: [line_item] }
    let(:line_item) { create :line_item, variant: variant, price: nil, quantity: 10 }
    let(:variant) { create :variant, price: 20 }
    let(:execute) { subject.call order: order, line_item: line_item }
    let(:value) { execute.value }

    context 'remove line item' do
      context 'with any quantity' do
        it 'with any quantity' do
          expect(order.amount).to eq 200
          expect { execute }.to change { order.line_items.count }.by(-1)
          expect(execute).to be_success
          expect(value).to eq line_item
          expect(order.amount).to eq 0
        end
      end

      context 'with many unique items' do
        let(:order) { create(:order_with_line_items, line_items_count: 2) }
        let(:line_item) {order.line_items.first}

        it 'from order with many unique items' do
          expect(order.amount).to eq 20
          expect(order.line_items.count).to eq 2
          expect { execute }.to change { order.line_items.count }.by(-1)
          expect(execute).to be_success
          expect(value).to eq line_item
          expect(order.amount).to eq 10
        end
      end
    end

    context 'given a shipment' do
      let(:shipment) { create :shipment }
      let(:options) { { shipment: shipment } }
      let(:execute) { subject.call order: order, line_item: line_item, options: options }

      it 'ensure shipment calls update_amounts instead of order calling ensure_updated_shipments' do
        expect(order).not_to receive(:ensure_updated_shipments)
        expect(shipment).to receive(:update_amounts)
        expect(execute).to be_success
      end
    end

    context 'not given a shipment' do
      let(:execute) { subject.call order: order, line_item: line_item }

      it 'ensures updated shipments' do
        expect(order).to receive(:ensure_updated_shipments)
        expect(execute).to be_success
      end
    end
  end
end
