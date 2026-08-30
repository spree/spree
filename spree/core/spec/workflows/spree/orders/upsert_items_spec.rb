require 'spec_helper'

module Spree
  RSpec.describe Orders::UpsertItems do
    let(:store) { create(:store) }
    let(:user) { create(:user) }
    let(:order) { create(:order, customer: user, store: store) }
    let(:variant) { create(:variant) }
    let(:variant2) { create(:variant) }

    before do
      [variant, variant2].each do |v|
        v.stock_levels.first.update!(count_on_hand: 10)
        store.products << v.product unless store.products.include?(v.product)
      end
    end

    describe '#call' do
      subject { described_class.call(order: order, items: items) }

      context 'with empty items' do
        let(:items) { [] }

        it 'returns success without changes' do
          expect(subject).to be_success
        end
      end

      context 'with nil items' do
        let(:items) { nil }

        it 'returns success without changes' do
          expect(subject).to be_success
        end
      end

      context 'creating new line items' do
        let(:items) do
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

        let(:items) do
          [{ variant_id: variant.prefixed_id, quantity: 2 }]
        end

        it 'sets quantity instead of incrementing' do
          expect(subject).to be_success
          expect(existing_line_item.reload.quantity).to eq(2)
        end
      end

      context 'mix of new and existing line items' do
        let!(:existing_line_item) { create(:line_item, order: order, variant: variant, quantity: 5) }

        let(:items) do
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
        let(:items) { [{ variant_id: variant.prefixed_id }] }

        it 'defaults quantity to 1' do
          expect(subject).to be_success
          expect(order.line_items.find_by(variant: variant).quantity).to eq(1)
        end
      end

      context 'with quantity zero and nothing to remove' do
        let(:items) { [{ variant_id: variant.prefixed_id, quantity: 0 }] }

        it 'skips the entry' do
          expect(subject).to be_success
          expect(order.line_items.count).to eq(0)
        end
      end

      context 'with negative quantity' do
        let(:items) { [{ variant_id: variant.prefixed_id, quantity: -3 }] }

        it 'skips the entry' do
          expect(subject).to be_success
          expect(order.line_items.count).to eq(0)
        end
      end

      # Zero is how an edited order says "this row is gone", so a whole order
      # can be submitted in one request rather than a delete per removed row.
      context 'with quantity zero on an existing line item' do
        let!(:existing_line_item) { create(:line_item, order: order, variant: variant, quantity: 5) }
        let(:items) { [{ variant_id: variant.prefixed_id, quantity: 0 }] }

        it 'removes the line item' do
          expect(subject).to be_success
          expect(order.line_items.reload).to be_empty
        end
      end

      context 'removing one line item while changing another' do
        let!(:kept) { create(:line_item, order: order, variant: variant2, quantity: 1) }
        let!(:removed) { create(:line_item, order: order, variant: variant, quantity: 5) }

        let(:items) do
          [
            { variant_id: variant.prefixed_id, quantity: 0 },
            { variant_id: variant2.prefixed_id, quantity: 4 }
          ]
        end

        it 'applies both in one pass' do
          expect(subject).to be_success
          expect(order.line_items.reload).to contain_exactly(kept)
          expect(kept.reload.quantity).to eq(4)
        end
      end

      # An upsert only touches what it is given — the screen sends every row,
      # so an omitted variant is not an instruction to delete it.
      context 'with a line item omitted from the payload' do
        let!(:untouched) { create(:line_item, order: order, variant: variant2, quantity: 2) }
        let(:items) { [{ variant_id: variant.prefixed_id, quantity: 1 }] }

        it 'leaves it alone' do
          expect(subject).to be_success
          expect(untouched.reload.quantity).to eq(2)
        end
      end

      context 'with metadata on a new line item' do
        let(:items) do
          [{ variant_id: variant.prefixed_id, quantity: 1, metadata: { 'gift' => true } }]
        end

        it 'sets metadata on new line item' do
          expect(subject).to be_success
          expect(order.line_items.find_by(variant: variant).metadata).to include('gift' => true)
        end
      end

      context 'merging metadata on existing line item' do
        let!(:existing_line_item) { create(:line_item, order: order, variant: variant, quantity: 1, metadata: { 'existing' => 'val' }) }

        let(:items) do
          [{ variant_id: variant.prefixed_id, quantity: 2, metadata: { 'new_key' => 'new_val' } }]
        end

        it 'merges new metadata into existing' do
          expect(subject).to be_success
          expect(existing_line_item.reload.metadata).to include('existing' => 'val', 'new_key' => 'new_val')
        end
      end

      context 'with invalid variant_id' do
        let(:items) { [{ variant_id: 'variant_invalid999', quantity: 1 }] }

        it 'raises RecordNotFound with variant details' do
          expect { subject }.to raise_error(ActiveRecord::RecordNotFound) do |error|
            expect(error.model).to eq('Spree::Variant')
            expect(error.message).to include('variant_invalid999')
          end
        end
      end

      context 'with blank variant_id in entry' do
        let(:items) { [{ variant_id: '', quantity: 1 }] }

        it 'skips the entry and returns success' do
          expect(subject).to be_success
          expect(order.line_items.count).to eq(0)
        end
      end

      context 'with nil variant_id in entry' do
        let(:items) { [{ variant_id: nil, quantity: 1 }] }

        it 'skips the entry and returns success' do
          expect(subject).to be_success
          expect(order.line_items.count).to eq(0)
        end
      end

      context 'with variant not available in order currency' do
        let(:order) { create(:order, customer: user, store: store, currency: 'GBP') }
        let(:items) { [{ variant_id: variant.prefixed_id, quantity: 1 }] }

        it 'returns failure with descriptive message' do
          expect(subject).to be_failure
          expect(subject.error.to_s).to include('is not available in GBP')
        end
      end

      context 'with variant from another store' do
        let(:other_store) { create(:store) }
        let(:other_variant) { create(:variant) }

        before do
          other_variant.stock_levels.first.update!(count_on_hand: 10)
          other_store.products << other_variant.product
        end

        let(:items) { [{ variant_id: other_variant.prefixed_id, quantity: 1 }] }

        it 'raises RecordNotFound (cross-store leakage prevented)' do
          expect { subject }.to raise_error(ActiveRecord::RecordNotFound) do |error|
            expect(error.model).to eq('Spree::Variant')
            expect(error.message).to include(other_variant.prefixed_id)
          end
        end
      end

      context 'with string keys in params' do
        let(:items) do
          [{ 'variant_id' => variant.prefixed_id, 'quantity' => 3 }]
        end

        it 'handles string keys' do
          expect(subject).to be_success
          expect(order.line_items.find_by(variant: variant).quantity).to eq(3)
        end
      end

      context 'with duplicate variant in items array' do
        let(:items) do
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

      context 'rolls back on failure mid-batch' do
        let(:items) do
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

        let(:items) do
          [{ variant_id: variant2.prefixed_id, quantity: 1 }]
        end

        it 'leaves unrelated line items unchanged' do
          expect(subject).to be_success
          expect(unrelated_line_item.reload.quantity).to eq(3)
        end
      end

      context 'with negotiated (manual) prices' do
        context 'creating a line at a negotiated price' do
          let(:items) { [{ variant_id: variant.prefixed_id, quantity: 10, price: '7.20' }] }

          it 'stamps the line manual at the given price' do
            expect(subject).to be_success
            line_item = order.line_items.sole
            expect(line_item.price).to eq(7.2)
            expect(line_item.price_source).to eq('manual')
            expect(line_item.price_list_id).to be_nil
          end
        end

        context 'editing quantity on a negotiated line without a price key' do
          let!(:line_item) do
            create(:line_item, order: order, variant: variant, quantity: 2,
                               price: 7.2, price_source: Spree::LineItem::MANUAL_PRICE_SOURCE)
          end
          let(:items) { [{ variant_id: variant.prefixed_id, quantity: 5 }] }

          it 'keeps the negotiated price' do
            expect(subject).to be_success
            expect(line_item.reload.quantity).to eq(5)
            expect(line_item.price).to eq(7.2)
            expect(line_item.price_source).to eq('manual')
          end
        end

        context 'reverting with an explicit nil price' do
          let!(:line_item) do
            create(:line_item, order: order, variant: variant, quantity: 2,
                               price: 7.2, price_source: Spree::LineItem::MANUAL_PRICE_SOURCE)
          end
          let(:items) { [{ variant_id: variant.prefixed_id, quantity: 2, price: nil }] }

          it 'clears the marker and re-prices through the resolver' do
            catalog_price = variant.price_in(order.currency).amount

            expect(subject).to be_success
            expect(line_item.reload.price).to eq(catalog_price)
            expect(line_item.price_source).to be_nil
          end
        end

        context 'with a non-numeric price' do
          let(:items) { [{ variant_id: variant.prefixed_id, quantity: 1, price: '12,50' }] }

          it 'refuses the batch rather than coercing, and says why' do
            expect(subject).to be_failure
            expect(subject.error.to_s).to include('non-negative number')
            expect(order.reload.line_items).to be_empty
          end
        end

        # BigDecimal parses both, and neither is negative — without a finite?
        # check they reach the insert and fail as a 500 rather than a 422.
        ['NaN', 'Infinity', '-Infinity', '-1'].each do |bad_price|
          context "with a price of #{bad_price}" do
            let(:items) { [{ variant_id: variant.prefixed_id, quantity: 1, price: bad_price }] }

            it 'refuses the batch' do
              expect(subject).to be_failure
              expect(order.reload.line_items).to be_empty
            end
          end
        end

        context 'on a placed order' do
          let!(:line_item) { create(:line_item, order: order, variant: variant, quantity: 2) }
          let(:items) { [{ variant_id: variant.prefixed_id, quantity: 2, price: '7.20' }] }

          before { order.update_columns(status: 'placed', completed_at: Time.current) }

          it 'refuses the price override — placed-order money edits are fees and discounts' do
            expect(subject).to be_failure
            expect(line_item.reload.price_source).to be_nil
          end
        end
      end
    end
  end
end
