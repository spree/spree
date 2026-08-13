require 'spec_helper'

module Spree
  RSpec.describe Carts::UpsertItems do
    let(:store) { create(:store) }
    let(:user) { create(:user) }
    let(:cart) { create(:cart, customer: user, store: store) }
    let(:variant) { create(:variant) }
    let(:variant2) { create(:variant) }

    before do
      [variant, variant2].each do |v|
        v.stock_items.first.update!(count_on_hand: 10)
        store.products << v.product unless store.products.include?(v.product)
      end
    end

    describe '#call' do
      subject { described_class.call(cart: cart, items: items) }

      context 'with empty items' do
        let(:items) { [] }

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
          cart.reload
          expect(cart.items.find_by(variant: variant).quantity).to eq(2)
          expect(cart.items.find_by(variant: variant2).quantity).to eq(3)
        end
      end

      context 'upserting existing line items' do
        let!(:existing_line_item) { create(:line_item, cart: cart, order: nil, variant: variant, quantity: 5) }

        let(:items) do
          [{ variant_id: variant.prefixed_id, quantity: 2 }]
        end

        it 'sets quantity instead of incrementing' do
          expect(subject).to be_success
          expect(existing_line_item.reload.quantity).to eq(2)
        end
      end

      context 'mix of new and existing line items' do
        let!(:existing_line_item) { create(:line_item, cart: cart, order: nil, variant: variant, quantity: 5) }

        let(:items) do
          [
            { variant_id: variant.prefixed_id, quantity: 1 },
            { variant_id: variant2.prefixed_id, quantity: 4 }
          ]
        end

        it 'updates existing and creates new' do
          expect(subject).to be_success
          cart.reload
          expect(existing_line_item.reload.quantity).to eq(1)
          expect(cart.items.find_by(variant: variant2).quantity).to eq(4)
        end
      end

      context 'with default quantity' do
        let(:items) { [{ variant_id: variant.prefixed_id }] }

        it 'defaults quantity to 1' do
          expect(subject).to be_success
          expect(cart.items.find_by(variant: variant).quantity).to eq(1)
        end
      end

      context 'with metadata' do
        let(:items) do
          [{ variant_id: variant.prefixed_id, quantity: 1, metadata: { 'gift' => true } }]
        end

        it 'sets metadata on new line item' do
          expect(subject).to be_success
          expect(cart.items.find_by(variant: variant).metadata).to include('gift' => true)
        end

        context 'merging metadata on existing line item' do
          let!(:existing_line_item) { create(:line_item, cart: cart, order: nil, variant: variant, quantity: 1, metadata: { 'existing' => 'val' }) }

          let(:items) do
            [{ variant_id: variant.prefixed_id, quantity: 2, metadata: { 'new_key' => 'new_val' } }]
          end

          it 'merges metadata' do
            expect(subject).to be_success
            expect(existing_line_item.reload.metadata).to include('existing' => 'val', 'new_key' => 'new_val')
          end
        end
      end

      context 'with invalid variant_id' do
        let(:items) do
          [{ variant_id: 'variant_invalid999', quantity: 1 }]
        end

        it 'raises RecordNotFound with variant details' do
          expect { subject }.to raise_error(ActiveRecord::RecordNotFound) do |error|
            expect(error.model).to eq('Spree::Variant')
            expect(error.message).to include('variant_invalid999')
          end
        end
      end

      context 'with nil items' do
        let(:items) { nil }

        it 'returns success without changes' do
          expect(subject).to be_success
        end
      end

      context 'with blank variant_id in entry' do
        let(:items) { [{ variant_id: '', quantity: 1 }] }

        it 'skips the entry and returns success' do
          expect(subject).to be_success
          expect(cart.items.count).to eq(0)
        end
      end

      context 'with nil variant_id in entry' do
        let(:items) { [{ variant_id: nil, quantity: 1 }] }

        it 'skips the entry and returns success' do
          expect(subject).to be_success
          expect(cart.items.count).to eq(0)
        end
      end

      context 'with variant not available in cart currency' do
        let(:cart) { create(:cart, customer: user, store: store, currency: 'GBP') }
        let(:items) { [{ variant_id: variant.prefixed_id, quantity: 1 }] }

        # Partial success: one unpriceable line must not cost the customer the
        # rest of the batch, so it comes back as a warning instead.
        it 'skips the item and reports it as a warning' do
          workflow = described_class.new
          result = workflow.call(cart: cart, items: items)

          expect(result).to be_success
          expect(cart.items.count).to eq(0)
          expect(workflow.warnings.first.code).to eq('currency_unavailable')
          expect(workflow.warnings.first.message).to include('is not available in GBP')
        end
      end

      context 'with variant from another store' do
        let(:other_store) { create(:store) }
        let(:other_variant) { create(:variant) }

        before do
          other_variant.stock_items.first.update!(count_on_hand: 10)
          other_store.products << other_variant.product
        end

        let(:items) { [{ variant_id: other_variant.prefixed_id, quantity: 1 }] }

        it 'raises RecordNotFound with variant details' do
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
          expect(cart.items.find_by(variant: variant).quantity).to eq(3)
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
          expect(cart.items.where(variant: variant).count).to eq(1)
          expect(cart.items.find_by(variant: variant).quantity).to eq(5)
        end
      end

      context 'sets correct price from variant' do
        let(:items) { [{ variant_id: variant.prefixed_id, quantity: 1 }] }

        it 'line item price matches variant price' do
          expect(subject).to be_success
          line_item = cart.items.find_by(variant: variant)
          expect(line_item.price).to eq(variant.amount_in(cart.currency))
        end
      end

      context 'recalculates cart totals' do
        let(:items) do
          [
            { variant_id: variant.prefixed_id, quantity: 2 },
            { variant_id: variant2.prefixed_id, quantity: 1 }
          ]
        end

        it 'updates cart item_total' do
          expect(subject).to be_success
          cart.reload
          expected_total = (variant.amount_in(cart.currency) * 2) + variant2.amount_in(cart.currency)
          expect(cart.item_total).to eq(expected_total)
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
          expect(cart.reload.items.find_by(variant: variant)).to be_nil
        end
      end

      context 'does not touch unrelated existing line items' do
        let!(:unrelated_line_item) { create(:line_item, cart: cart, order: nil, variant: variant, quantity: 3) }

        let(:items) do
          [{ variant_id: variant2.prefixed_id, quantity: 1 }]
        end

        it 'leaves unrelated line items unchanged' do
          expect(subject).to be_success
          expect(unrelated_line_item.reload.quantity).to eq(3)
        end
      end
    end

    describe 'the validate hook' do
      after { Spree.hooks.clear! }

      let(:items) do
        [
          { variant_id: variant.prefixed_id, quantity: 1 },
          { variant_id: variant2.prefixed_id, quantity: 99 }
        ]
      end

      it 'skips a rejected item and applies the rest' do
        Spree.hooks.register('carts.upsert_items.validate') do |flow|
          next if flow.quantity <= 10

          flow.errors.add(:quantity, :purchase_limit_exceeded, message: 'at most 10 per item')
          flow.reject!
        end

        workflow = described_class.new
        result = workflow.call(cart: cart, items: items)

        expect(result).to be_success
        expect(cart.items.map(&:variant)).to eq([variant])

        warning = workflow.warnings.sole
        expect(warning.item_index).to eq(1)
        expect(warning.variant).to eq(variant2)
        expect(warning.code).to eq('purchase_limit_exceeded')
        expect(warning.message).to eq('Quantity at most 10 per item')
      end

      # Each item is judged on its own — a rejection must not leak errors
      # into the next item's dispatch.
      it 'validates every item independently' do
        seen = []
        Spree.hooks.register('carts.upsert_items.validate') do |flow|
          seen << [flow.variant, flow.quantity]
          flow.reject!('nope') if flow.quantity == 99
        end

        described_class.call(cart: cart, items: items)

        expect(seen).to eq([[variant, 1], [variant2, 99]])
      end

      it 'exposes the whole batch for cross-item rules' do
        batch_size = nil
        Spree.hooks.register('carts.upsert_items.validate') { |flow| batch_size = flow.items.size }

        described_class.call(cart: cart, items: items)

        expect(batch_size).to eq(2)
      end
    end

    # A line that cannot be saved is that line's problem. Failing the batch
    # would throw away every other item the customer still wants.
    describe 'a line item that will not save' do
      let(:items) do
        [
          { variant_id: variant.prefixed_id, quantity: 1 },
          { variant_id: variant2.prefixed_id, quantity: 999 }
        ]
      end

      before { variant2.stock_items.first.update!(count_on_hand: 1, backorderable: false) }

      it 'warns and keeps the rest of the batch' do
        workflow = described_class.new
        result = workflow.call(cart: cart, items: items)

        expect(result).to be_success
        expect(cart.reload.items.map(&:variant)).to eq([variant])
        expect(workflow.warnings.sole.item_index).to eq(1)
      end
    end

    describe 'removals' do
      let!(:line_item) { create(:line_item, cart: cart, order: nil, variant: variant, quantity: 2) }

      it 'removes the line item when quantity is zero' do
        result = described_class.call(cart: cart, items: [{ variant_id: variant.prefixed_id, quantity: 0 }])

        expect(result).to be_success
        expect(cart.reload.items).to be_empty
      end

      it 'applies edits and removals in one pass' do
        result = described_class.call(cart: cart, items: [
          { variant_id: variant.prefixed_id, quantity: 0 },
          { variant_id: variant2.prefixed_id, quantity: 3 }
        ])

        expect(result).to be_success
        expect(cart.reload.items.map(&:variant)).to eq([variant2])
        expect(cart.items.sole.quantity).to eq(3)
      end
    end

    # The reason this is a batch workflow rather than a loop over AddItem:
    # the money math runs once no matter how many items arrive.
    it 'recalculates the cart once for the whole batch' do
      recalculate = Spree.cart_recalculate_workflow
      expect(recalculate).to receive(:new).once.and_call_original

      described_class.call(cart: cart, items: [
        { variant_id: variant.prefixed_id, quantity: 1 },
        { variant_id: variant2.prefixed_id, quantity: 2 }
      ])
    end
  end
end
