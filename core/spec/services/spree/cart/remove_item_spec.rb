require 'spec_helper'

module Spree
  describe Cart::RemoveItem do
    subject { described_class }

    let(:order) { create :order, line_items: [line_item] }
    let(:line_item) { create :line_item, variant: variant, price: nil }
    let(:variant) { create :variant, price: 20 }
    let(:execute) { subject.call order: order, variant: variant }
    let(:value) { execute.value }

    context 'single line item' do
      it 'remove item from order' do
        expect(order.amount).to eq 20
        expect { execute }.to change { order.line_items.count }.by(-1)
        expect(execute).to be_success
        expect(value).to eq line_item
        expect(order.amount).to eq 0
      end
    end

    context 'line items with more than one quantity' do
      let(:line_item) { create :line_item, variant: variant, quantity: 2, price: nil }
      let(:execute) { subject.call order: order, variant: variant }

      it 'remove quantity from line item' do
        expect { execute }.to change(order, :amount).by(-20)
        expect(execute).to be_success
        expect(value).to eq line_item
        line_item.reload
        expect(order.line_items.count).to eq 1
        expect(line_item.quantity).to eq 1
      end
    end

    context 'raise error' do
      let(:variant_2) { create :variant }
      let(:execute) { subject.call order: order, variant: variant_2 }

      it 'when try remove non existing item' do
        expect { execute }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'given a shipment' do
      let(:shipment) { create :shipment }
      let(:options) { { shipment: shipment } }
      let(:execute) { subject.call order: order, variant: variant, options: options }

      it 'ensure shipment calls update_amounts instead of order calling ensure_updated_shipments' do
        expect(order).not_to receive(:ensure_updated_shipments)
        expect(shipment).to receive(:update_amounts)
        expect(execute).to be_success
      end
    end

    context 'not given a shipment' do
      let(:execute) { subject.call order: order, variant: variant }

      it 'ensures updated shipments' do
        expect(order).to receive(:ensure_updated_shipments)
        expect(execute).to be_success
      end
    end

    context 'when store_credits payment' do
      let!(:payment) { create(:store_credit_payment, order: order) }
      let(:execute) { subject.call order: order, variant: variant }

      it do
        expect { execute }.to change { order.payments.store_credits.count }.by(-1)
      end
    end
  end
end
