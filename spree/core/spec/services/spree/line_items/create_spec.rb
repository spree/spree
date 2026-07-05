require 'spec_helper'

module Spree
  describe LineItems::Create do
    subject { described_class }

    let(:order) { create :order }
    let(:variant) { create :variant, price: 20 }
    let(:execute) { subject.call(order: order, line_item_attributes: attributes_for(:line_item, variant: variant, currency: order.currency)) }
    let(:value) { execute.value }
    let(:line_item_attributes) { { quantity: 11 } }

    context 'creates a line item' do
      it 'with any quantity' do
        expect(order.amount).to eq(0)
        expect(order.quantity).to eq(0)
        expect { execute }.to change(order, :quantity).by(1)
        expect(execute).to be_success
        expect(value).to be_kind_of(Spree::LineItem)
      end
    end
  end
end
