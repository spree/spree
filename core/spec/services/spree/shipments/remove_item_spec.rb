require 'spec_helper'

module Spree
  describe Shipments::RemoveItem do
    subject { described_class }

    let(:store) { create(:store) }
    let(:order) { create(:order_ready_to_ship, store: store, user: nil, email: 'john@snow.org') }
    let(:variant) { shipment.line_items.first.variant }
    let(:shipment) { order.shipments.first }
    let(:line_item) { shipment.line_items.last }

    let(:execute) { subject.call(params) }
    let(:value) { execute.value }

    let(:params) do
      {
        shipment: shipment,
        variant_id: variant.id,
        quantity: line_item.quantity
      }
    end

    context 'valid attributes' do
      shared_examples 'successful' do
        it { expect(execute.success?).to eq(true) }
      end

      shared_examples 'removes line item' do
        it { expect { execute }.to change(order.line_items, :count).by(-1) }
      end

      shared_examples 'removes shipment' do
        it { expect { execute }.to change(order.shipments, :count).by(-1) }
        it { expect(execute.value).to eq(:shipment_deleted) }
      end

      context 'part of the line item qty removed' do
        before { line_item.update!(quantity: 2) }

        let(:params) do
          {
            shipment: shipment,
            variant_id: variant.id,
            quantity: 1
          }
        end

        it_behaves_like 'successful'

        it { expect { execute }.not_to change(order.shipments, :count) }
        it { expect { execute }.not_to change(order.line_items, :count) }

        it 'decreases line item quantity' do
          expect(line_item.quantity).to eq(2)
          execute
          expect(line_item.reload.quantity).to eq(1)
        end

        it { expect(execute.value).to be_kind_of(Spree::Shipment) }
        it { expect(execute.value.id).to eq(shipment.id) }
      end

      context 'entire shipment & line item qty removed' do
        it_behaves_like 'successful'
        it_behaves_like 'removes line item'
        it_behaves_like 'removes shipment'
      end

      context 'no quantity is passed' do
        let(:params) do
          {
            shipment: shipment,
            variant_id: variant.id
          }
        end

        it_behaves_like 'successful'
        it_behaves_like 'removes line item'
        it_behaves_like 'removes shipment'
      end
    end

    context 'missing variant' do
      let(:params) do
        {
          shipment: shipment,
          variant_id: 141223453,
          quantity: 2
        }
      end

      it { expect(execute.success?).to eq(false) }
      it { expect(execute.error.to_s).to eq('variant_not_found') }
    end
  end
end
