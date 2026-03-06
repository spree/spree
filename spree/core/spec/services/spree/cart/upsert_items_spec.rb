require 'spec_helper'

module Spree
  RSpec.describe Cart::UpsertItems do
    let(:store) { create(:store) }
    let(:user) { create(:user) }
    let(:order) { create(:order, user: user, store: store) }
    let(:variant) { create(:variant) }
    let(:variant2) { create(:variant) }

    before do
      [variant, variant2].each do |v|
        v.stock_items.first.update!(count_on_hand: 10)
        store.products << v.product unless store.products.include?(v.product)
      end
    end

    describe '#call' do
      subject { described_class.call(order: order, line_items: line_items) }

      context 'with empty line_items' do
        let(:line_items) { [] }

        it 'returns success without changes' do
          expect(subject).to be_success
        end
      end

      context 'creating new line items' do
        let(:line_items) do
          [
            { variant_id: variant.prefixed_id, quantity: 2 },
            { variant_id: variant2.prefixed_id, quantity: 3 }
          ]
        end

        it 'creates line items with correct quantities' do
          expect(subject).to be_success
          order.reload
          expect(order.line_items.find_by(variant: variant).quantity).to eq(2)
          expect(order.line_items.find_by(variant: variant2).quantity).to eq(3)
        end
      end

      context 'upserting existing line items' do
        let!(:existing_line_item) { create(:line_item, order: order, variant: variant, quantity: 5) }

        let(:line_items) do
          [{ variant_id: variant.prefixed_id, quantity: 2 }]
        end

        it 'sets quantity instead of incrementing' do
          expect(subject).to be_success
          expect(existing_line_item.reload.quantity).to eq(2)
        end
      end

      context 'mix of new and existing line items' do
        let!(:existing_line_item) { create(:line_item, order: order, variant: variant, quantity: 5) }

        let(:line_items) do
          [
            { variant_id: variant.prefixed_id, quantity: 1 },
            { variant_id: variant2.prefixed_id, quantity: 4 }
          ]
        end

        it 'updates existing and creates new' do
          expect(subject).to be_success
          order.reload
          expect(existing_line_item.reload.quantity).to eq(1)
          expect(order.line_items.find_by(variant: variant2).quantity).to eq(4)
        end
      end

      context 'with default quantity' do
        let(:line_items) { [{ variant_id: variant.prefixed_id }] }

        it 'defaults quantity to 1' do
          expect(subject).to be_success
          expect(order.line_items.find_by(variant: variant).quantity).to eq(1)
        end
      end

      context 'with metadata' do
        let(:line_items) do
          [{ variant_id: variant.prefixed_id, quantity: 1, metadata: { 'gift' => true } }]
        end

        it 'sets metadata on new line item' do
          expect(subject).to be_success
          expect(order.line_items.find_by(variant: variant).metadata).to include('gift' => true)
        end

        context 'merging metadata on existing line item' do
          let!(:existing_line_item) { create(:line_item, order: order, variant: variant, quantity: 1, private_metadata: { 'existing' => 'val' }) }

          let(:line_items) do
            [{ variant_id: variant.prefixed_id, quantity: 2, metadata: { 'new_key' => 'new_val' } }]
          end

          it 'merges metadata' do
            expect(subject).to be_success
            expect(existing_line_item.reload.metadata).to include('existing' => 'val', 'new_key' => 'new_val')
          end
        end
      end

      context 'with invalid variant_id' do
        let(:line_items) do
          [{ variant_id: 'variant_invalid999', quantity: 1 }]
        end

        it 'raises RecordNotFound with variant details' do
          expect { subject }.to raise_error(ActiveRecord::RecordNotFound) do |error|
            expect(error.model).to eq('Spree::Variant')
            expect(error.message).to include('variant_invalid999')
          end
        end
      end

      context 'with nil line_items' do
        let(:line_items) { nil }

        it 'returns success without changes' do
          expect(subject).to be_success
        end
      end

      context 'with blank variant_id in entry' do
        let(:line_items) { [{ variant_id: '', quantity: 1 }] }

        it 'skips the entry and returns success' do
          expect(subject).to be_success
          expect(order.line_items.count).to eq(0)
        end
      end

      context 'with nil variant_id in entry' do
        let(:line_items) { [{ variant_id: nil, quantity: 1 }] }

        it 'skips the entry and returns success' do
          expect(subject).to be_success
          expect(order.line_items.count).to eq(0)
        end
      end

      context 'with variant not available in order currency' do
        let(:order) { create(:order, user: user, store: store, currency: 'GBP') }
        let(:line_items) { [{ variant_id: variant.prefixed_id, quantity: 1 }] }

        it 'returns failure with message' do
          expect(subject).to be_failure
          expect(subject.error.to_s).to include('is not available in GBP')
        end
      end

      context 'with variant from another store' do
        let(:other_store) { create(:store) }
        let(:other_variant) { create(:variant) }

        before do
          other_variant.stock_items.first.update!(count_on_hand: 10)
          other_store.products << other_variant.product
        end

        let(:line_items) { [{ variant_id: other_variant.prefixed_id, quantity: 1 }] }

        it 'raises RecordNotFound with variant details' do
          expect { subject }.to raise_error(ActiveRecord::RecordNotFound) do |error|
            expect(error.model).to eq('Spree::Variant')
            expect(error.message).to include(other_variant.prefixed_id)
          end
        end
      end

      context 'with string keys in params' do
        let(:line_items) do
          [{ 'variant_id' => variant.prefixed_id, 'quantity' => 3 }]
        end

        it 'handles string keys' do
          expect(subject).to be_success
          expect(order.line_items.find_by(variant: variant).quantity).to eq(3)
        end
      end

      context 'with duplicate variant in line_items array' do
        let(:line_items) do
          [
            { variant_id: variant.prefixed_id, quantity: 2 },
            { variant_id: variant.prefixed_id, quantity: 5 }
          ]
        end

        it 'last entry wins' do
          expect(subject).to be_success
          expect(order.line_items.where(variant: variant).count).to eq(1)
          expect(order.line_items.find_by(variant: variant).quantity).to eq(5)
        end
      end

      context 'sets correct price from variant' do
        let(:line_items) { [{ variant_id: variant.prefixed_id, quantity: 1 }] }

        it 'line item price matches variant price' do
          expect(subject).to be_success
          line_item = order.line_items.find_by(variant: variant)
          expect(line_item.price).to eq(variant.price)
        end
      end

      context 'recalculates order totals' do
        let(:line_items) do
          [
            { variant_id: variant.prefixed_id, quantity: 2 },
            { variant_id: variant2.prefixed_id, quantity: 1 }
          ]
        end

        it 'updates order item_total' do
          expect(subject).to be_success
          order.reload
          expected_total = (variant.price * 2) + variant2.price
          expect(order.item_total).to eq(expected_total)
        end
      end

      context 'rolls back on failure mid-batch' do
        let(:line_items) do
          [
            { variant_id: variant.prefixed_id, quantity: 1 },
            { variant_id: 'variant_doesnotexist', quantity: 1 }
          ]
        end

        it 'does not persist partial changes' do
          expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
          expect(order.reload.line_items.find_by(variant: variant)).to be_nil
        end
      end

      context 'does not touch unrelated existing line items' do
        let!(:unrelated_line_item) { create(:line_item, order: order, variant: variant, quantity: 3) }

        let(:line_items) do
          [{ variant_id: variant2.prefixed_id, quantity: 1 }]
        end

        it 'leaves unrelated line items unchanged' do
          expect(subject).to be_success
          expect(unrelated_line_item.reload.quantity).to eq(3)
        end
      end
    end
  end
end
