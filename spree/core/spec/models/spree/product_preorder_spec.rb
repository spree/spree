require 'spec_helper'

# Pre-order is a per-variant "buy before it's in stock" label plus a "ships by"
# date. Overselling — whether framed as a backorder or a pre-order — is bounded
# by the variant's backorder_limit: empty means unlimited, a value caps how many
# units may be sold beyond available stock.
RSpec.describe 'Pre-order', type: :model do
  let(:store) { @default_store }
  let(:product) { create(:product, status: 'active') }
  let(:variant) { create(:variant, product: product, price: 20) }
  let(:stock_item) { variant.stock_items.first }

  def quantifier
    Spree::Stock::Quantifier.new(variant)
  end

  describe 'Spree::Variant#preorder?' do
    it 'is true when flagged with no ships-by date (open-ended)' do
      variant.update!(preorderable: true, preorder_ships_at: nil)
      expect(variant.preorder?).to be true
    end

    it 'is true when flagged and the ships-by date is in the future' do
      variant.update!(preorderable: true, preorder_ships_at: 2.months.from_now)
      expect(variant.preorder?).to be true
    end

    it 'is false once the ships-by date has passed' do
      variant.update!(preorderable: true, preorder_ships_at: 1.day.ago)
      expect(variant.preorder?).to be false
    end

    it 'is false when not flagged' do
      variant.update!(preorderable: false, preorder_ships_at: 2.months.from_now)
      expect(variant.preorder?).to be false
    end

    it 'is independent of the publish date — applies even when the product is already live' do
      variant.update!(preorderable: true)
      expect(product.available?).to be true # live / published
      expect(variant.preorder?).to be true
    end

    it 'is false when the product is not active (relaxes only the publish-date gate)' do
      variant.update!(preorderable: true)
      product.update!(status: 'archived')
      expect(variant.preorder?).to be false
    end
  end

  describe 'pre-order does not bypass the product status' do
    it 'cannot supply an archived product even when the variant is preorderable' do
      variant.update!(preorderable: true)
      stock_item.set_count_on_hand(5)
      product.update!(status: 'archived')
      expect(quantifier.can_supply?(1)).to be false
    end
  end

  # The oversell cap. Empty = unlimited; a value bounds how far below zero the
  # variant may sell, whether the oversell is a backorder or a pre-order.
  describe 'backorder_limit' do
    before do
      stock_item.update!(backorderable: false)
      stock_item.set_count_on_hand(0)
    end

    context 'pre-order with no backorder_limit (empty = unlimited)' do
      before { variant.update!(preorderable: true, backorder_limit: nil) }

      it 'is purchasable with no stock and no backorder' do
        expect(variant.purchasable?).to be true
      end

      it 'can supply any quantity' do
        expect(quantifier.can_supply?(10_000)).to be true
      end
    end

    context 'pre-order with a backorder_limit (capped)' do
      before { variant.update!(preorderable: true, backorder_limit: 5) }

      it 'is purchasable within the limit' do
        expect(variant.purchasable?).to be true
        expect(quantifier.can_supply?(5)).to be true
      end

      it 'cannot supply beyond the limit' do
        expect(quantifier.can_supply?(6)).to be false
      end

      it 'combines on-hand stock with the limit' do
        stock_item.set_count_on_hand(2)
        expect(quantifier.can_supply?(7)).to be true
        expect(quantifier.can_supply?(8)).to be false
      end

      it 'is not purchasable once the limit is used up' do
        stock_item.set_count_on_hand(-5) # 5 units already oversold
        expect(quantifier.can_supply?(1)).to be false
        expect(variant.purchasable?).to be false
      end
    end

    # The limit is universal — it caps a plain backorder too, not just pre-orders.
    context 'plain backorder (not a pre-order)' do
      before { stock_item.update!(backorderable: true) }

      it 'caps the backorder at the limit' do
        variant.update!(backorder_limit: 3)
        expect(quantifier.can_supply?(3)).to be true
        expect(quantifier.can_supply?(4)).to be false
      end

      it 'is unlimited when the limit is empty (legacy behaviour)' do
        variant.update!(backorder_limit: nil)
        expect(quantifier.can_supply?(9_999)).to be true
      end
    end
  end

  describe 'Spree::Product' do
    it '#preorder? is true when a variant is on pre-order' do
      variant.update!(preorderable: true)
      expect(product.reload.preorder?).to be true
    end

    it '#preorder? is false when no variant is on pre-order' do
      variant.update!(preorderable: false)
      expect(product.reload.preorder?).to be false
    end

    it '#preorder_ships_at returns the latest ships-by date among pre-order variants' do
      variant.update!(preorderable: true, preorder_ships_at: 1.month.from_now)
      latest = create(:variant, product: product, price: 20, preorderable: true, preorder_ships_at: 3.months.from_now)
      expect(product.reload.preorder_ships_at).to be_within(1.second).of(latest.preorder_ships_at)
    end
  end

  # "Coming soon": a product scheduled to publish later (future published_at on
  # the current channel) can still be pre-ordered before its publish date.
  describe 'scheduled launch (future publish date)' do
    let(:channel) { store.default_channel }
    let(:publication) { product.product_publications.find_or_create_by!(channel: channel) }

    before do
      variant.update!(preorderable: true, backorder_limit: 5)
      stock_item.update!(backorderable: false)
      stock_item.set_count_on_hand(0)
      publication.update!(published_at: 2.months.from_now) # not yet published
      product.product_publications.reset
    end

    it 'is embargoed (not available) but is a pre-order' do
      expect(variant.available?).to be false
      expect(variant.preorder?).to be true
    end

    it 'can be supplied before the publish date, capped by the backorder_limit' do
      expect(quantifier.can_supply?(5)).to be true
      expect(quantifier.can_supply?(6)).to be false
    end
  end
end
