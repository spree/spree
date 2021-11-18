require 'spec_helper'

module Spree
  describe Shipments::Create do
    subject { described_class }

    let(:store) { create(:store) }
    let(:order) { create(:order_with_totals, store: store, user: nil, email: 'john@snow.org') }
    let(:product) { create(:product_in_stock, stores: [store]) }
    let(:variant) { product.master }
    let(:stock_location) { product.stock_items.first.stock_location }

    let(:execute) { subject.call(store: store, shipment_attributes: shipment_attributes) }
    let(:value) { execute.value }

    let(:shipment_attributes) do
      {
        order_id: order.id,
        variant_id: variant.id,
        quantity: 2,
        stock_location_id: stock_location.id
      }
    end

    let(:shipment) { order.shipments.last }
    let(:line_item) { shipment.line_items.last }

    context 'valid attributes' do
      shared_context 'creates a shipment' do
        it 'creates new shipment record' do
          expect { execute }.to change(order.shipments, :count).by(1)
          expect(shipment.stock_location).to eq(stock_location)
        end

        it { expect(execute.success?).to eq(true) }
        it { expect(execute.value).to be_kind_of(Spree::Shipment) }
      end

      shared_context 'creates a line item' do
        it 'creates new line item record' do
          expect { execute }.to change(order.line_items, :count).by(1)
          expect(line_item.variant).to eq(variant)
          expect(line_item.quantity).to eq(2)
        end
      end

      context 'without pre-existing line item' do
        it_behaves_like 'creates a shipment'
        it_behaves_like 'creates a line item'
      end

      context 'with existing line item' do
        let!(:old_line_item) { create(:line_item, order: order, variant: variant, quantity: 2) }

        it_behaves_like 'creates a shipment'

        it 'does not create a new line item' do
          expect { execute }.not_to change(order.line_items, :count)
        end

        it 'adds quantity to the existing line item' do
          expect(old_line_item.quantity).to eq(2)
          execute
          expect(old_line_item.reload.quantity).to eq(4)
        end

        it 'updates line item totals' do
          expect(old_line_item.total).to eq(20)
          execute
          expect(old_line_item.reload.total).to eq(BigDecimal(40)) # 4 x 10 unit price
        end
      end
    end

    context 'missing variant' do
      let(:shipment_attributes) do
        {
          order_id: order.id,
          variant_id: 1312415,
          quantity: 1,
          stock_location_id: stock_location.id
        }
      end

      it { expect(execute.success?).to eq(false) }
      it { expect(execute.error.to_s).to eq('variant_not_found') }
    end

    context 'missing order' do
      let(:shipment_attributes) do
        {
          order_id: 1231243,
          variant_id: variant.id,
          quantity: 1,
          stock_location_id: stock_location.id
        }
      end

      it { expect(execute.success?).to eq(false) }
      it { expect(execute.error.to_s).to eq('order_not_found') }
    end

    context 'missing stock location' do
      let(:shipment_attributes) do
        {
          order_id: order.id,
          variant_id: variant.id,
          quantity: 1,
          stock_location_id: 1341234
        }
      end

      it { expect(execute.success?).to eq(false) }
      it { expect(execute.error.to_s).to eq('stock_location_not_found') }
    end

    xcontext 'invalid attributes' do
      let(:shipment_attributes) do
        {
          order_id: order.id,
          variant_id: variant.id,
          quantity: 'invalid', # this will not work as we're doing `to_i` casting
          stock_location_id: stock_location.id
        }
      end

      it { expect(execute.success?).to eq(false) }
      it { expect(execute.error.value).to be_kind_of(ActiveModel::Errors) }
    end
  end
end
