require 'spec_helper'

RSpec.describe Spree::Carts::Merge do
  let(:store) { @default_store }
  let(:variant) { create(:variant) }

  let(:cart) { create(:cart, store: store) }
  let(:other_cart) { create(:cart, store: store) }

  before { Spree.hooks.clear! }
  after { Spree.hooks.clear! }

  describe 'merging' do
    it 'absorbs the quantity of a matching item, gifts included, and destroys the drained cart' do
      cart.line_items.create!(variant: variant, quantity: 1, currency: cart.currency)
      other_line_item = other_cart.line_items.create!(variant: variant, quantity: 2, currency: other_cart.currency)
      create(:line_item_gift, line_item: other_line_item)

      result = described_class.call(cart: cart, other_cart: other_cart)

      expect(result).to be_success
      expect(cart.reload.line_items.count).to eq(1)
      expect(cart.line_items.first.quantity).to eq(3)
      expect(cart.line_items.first.gifted_quantity).to eq(1)
      expect { other_cart.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'does not carry a gift the surviving line already holds from the same promotion' do
      gift = create(:line_item_gift, line_item: cart.line_items.create!(variant: variant, quantity: 1, currency: cart.currency))
      create(:line_item_gift, line_item: other_cart.line_items.create!(variant: variant, quantity: 1, currency: other_cart.currency),
                              promotion_action: gift.promotion_action)

      described_class.call(cart: cart, other_cart: other_cart)

      line_item = cart.reload.line_items.first
      expect([line_item.quantity, line_item.gifted_quantity]).to eq([1, 1])
    end

    it "drops another promotion's gift rather than carry two gifts on one line" do
      gift = create(:line_item_gift, line_item: cart.line_items.create!(variant: variant, quantity: 1, currency: cart.currency))
      create(:line_item_gift, line_item: other_cart.line_items.create!(variant: variant, quantity: 1, currency: other_cart.currency))

      described_class.call(cart: cart, other_cart: other_cart)

      line_item = cart.reload.line_items.first
      expect(line_item.quantity).to eq(1)
      expect(line_item.gifts).to contain_exactly(gift)
    end

    it 'moves a non-matching item across' do
      other_variant = create(:variant)
      cart.line_items.create!(variant: variant, quantity: 1, currency: cart.currency)
      other_cart.line_items.create!(variant: other_variant, quantity: 1, currency: other_cart.currency)

      described_class.call(cart: cart, other_cart: other_cart)

      expect(cart.reload.line_items.map(&:variant)).to match_array([variant, other_variant])
    end

    it 'returns the cart untouched when there is nothing to merge' do
      expect(described_class.call(cart: cart, other_cart: nil)).to be_success
      expect(described_class.call(cart: cart, other_cart: cart)).to be_success
    end

    it 'keeps a currency-mismatched cart instead of destroying it' do
      allow(other_cart).to receive(:currency).and_return('EUR')

      result = described_class.call(cart: cart, other_cart: other_cart)

      expect(result).to be_failure
      expect(other_cart.reload).to be_persisted
    end
  end

  describe 'hooks' do
    it 'lets a validate handler veto the merge before anything moves' do
      other_cart.line_items.create!(variant: variant, quantity: 2, currency: other_cart.currency)

      Spree.hooks.register('carts.merge.validate') { |flow| flow.reject!('merging is disabled') }

      result = described_class.call(cart: cart, other_cart: other_cart)

      expect(result).to be_failure
      expect(result.error.to_s).to eq('merging is disabled')
      expect(cart.reload.line_items).to be_empty
      expect(other_cart.reload.line_items.count).to eq(1)
    end

    it 'runs after_merge once the carts are folded together' do
      other_cart.line_items.create!(variant: variant, quantity: 1, currency: other_cart.currency)

      merged_count = nil
      Spree.hooks.register('carts.merge.after_merge') { |flow| merged_count = flow.cart.line_items.count }

      described_class.call(cart: cart, other_cart: other_cart)

      expect(merged_count).to eq(1)
    end
  end
end
