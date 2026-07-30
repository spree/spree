require 'spec_helper'

module Spree
  describe LineItems::Destroy do
    subject { described_class }

    let(:order) { create :order, line_items: [line_item] }
    let(:line_item) { create :line_item, variant: variant, price: nil, quantity: 10 }
    let(:variant) { create :variant, price: 20 }
    let(:execute) { subject.call(line_item: line_item) }
    let(:value) { execute.value }

    context 'remove line item' do
      it 'with any quantity' do
        expect(order.amount).to eq 200
        expect { execute }.to change { order.line_items.count }.by(-1)
        expect(execute).to be_success
        expect(value).to eq line_item
        order.reload
        expect(order.amount).to eq 0
      end
    end

    context 'not given a shipment' do
      let(:execute) { subject.call(line_item: line_item) }

      it 'ensures updated shipments' do
        expect(order).to receive(:ensure_updated_shipments)
        expect(execute).to be_success
      end
    end
  end
end
