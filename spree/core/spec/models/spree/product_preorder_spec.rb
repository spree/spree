require 'spec_helper'

# Pre-order is a per-variant "buy before it's in stock" label plus a "ships by"
# date. It is decoupled from publishing: purchasability and the cap come from
# ordinary stock/backorder, the flag and date only add the label and promise.
RSpec.describe 'Pre-order', type: :model do
  let(:store) { @default_store }
  let(:product) { create(:product, status: 'active') }
  let(:variant) { create(:variant, product: product, price: 20) }

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

    it 'is independent of publishing — applies even when the product is already live' do
      variant.update!(preorderable: true)
      expect(product.available?).to be true # live / published
      expect(variant.preorder?).to be true
    end
  end

  describe 'purchasability comes from stock, not the pre-order flag' do
    before { variant.update!(preorderable: true) }

    it 'is purchasable from an incoming stock count (which is the cap)' do
      variant.stock_items.first.update!(backorderable: false)
      variant.stock_items.first.set_count_on_hand(5)
      expect(variant.purchasable?).to be true
    end

    it 'is purchasable when backorderable (unlimited)' do
      variant.stock_items.first.update!(backorderable: true)
      variant.stock_items.first.set_count_on_hand(0)
      expect(variant.purchasable?).to be true
    end

    it 'is not purchasable with no stock and no backorder (nothing to pre-sell)' do
      variant.stock_items.first.update!(backorderable: false)
      variant.stock_items.first.set_count_on_hand(0)
      expect(variant.purchasable?).to be false
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
      variant.update!(preorderable: true)
      variant.stock_items.first.update!(backorderable: false)
      variant.stock_items.first.set_count_on_hand(5)
      publication.update!(published_at: 2.months.from_now) # not yet published
      product.product_publications.reset
    end

    it 'is embargoed (not available) but is a pre-order' do
      expect(variant.available?).to be false
      expect(variant.preorder?).to be true
    end

    it 'can be supplied before the publish date, capped by stock' do
      expect(Spree::Stock::Quantifier.new(variant).can_supply?(5)).to be true
      expect(Spree::Stock::Quantifier.new(variant).can_supply?(6)).to be false
    end
  end
end
