require 'spec_helper'

RSpec.describe 'Inventory providers' do
  let(:store) { @default_store }
  let(:stock_location) { create(:stock_location, store: store) }
  let(:variant) { create(:variant) }

  before do
    variant.stock_levels.destroy_all
    # adjust_count_on_hand: false — the factory otherwise adds ten on top of
    # whatever count_on_hand was asked for.
    create(:stock_level, variant: variant, stock_location: stock_location,
                        count_on_hand: 10, backorderable: false, adjust_count_on_hand: false)
    variant.stock_levels.reload
  end

  describe 'the default store' do
    it 'counts Spree stock records, exactly as before providers existed' do
      expect(store.inventory_provider_instance).to be_a(Spree::InventoryProvider::Internal)
      expect(Spree::Stock::Quantifier.new(variant).total_on_hand).to eq(10)
    end
  end

  describe 'counting an external system rows' do
    # What an external provider returns: rows shaped like stock items but never
    # saved, so nothing can write a remote count into Spree's own records.
    def external_rows(count_on_hand:, backorderable: false)
      [Spree::StockLevel.new(variant: variant, stock_location: stock_location,
                            count_on_hand: count_on_hand, backorderable: backorderable)]
    end

    it 'counts the rows it is handed rather than the local ones' do
      quantifier = Spree::Stock::Quantifier.new(variant, stock_levels: external_rows(count_on_hand: 3))

      expect(quantifier.total_on_hand).to eq(3)
    end

    it 'answers can_supply? from those rows' do
      quantifier = Spree::Stock::Quantifier.new(variant, stock_levels: external_rows(count_on_hand: 3))

      expect(quantifier.can_supply?(3)).to be(true)
      expect(quantifier.can_supply?(4)).to be(false)
    end

    # A provider that knows nothing about the variant returns no rows at all.
    # That is an answer — zero — not a reason to fall back to local records
    # (which would let a variant the warehouse has never heard of be sold).
    it 'treats no rows from the provider as nothing in stock' do
      quantifier = Spree::Stock::Quantifier.new(variant, stock_levels: [])

      expect(quantifier.total_on_hand).to eq(0)
      expect(quantifier.can_supply?(1)).to be(false)
    end

    it 'honours backorderable as the external system reports it' do
      quantifier = Spree::Stock::Quantifier.new(
        variant, stock_levels: external_rows(count_on_hand: 0, backorderable: true)
      )

      expect(quantifier.can_supply?(50)).to be(true)
    end

    # The external system knows nothing about our carts, so a hold taken during
    # checkout has to keep reducing what the next shopper can buy. The rows
    # carry no id to match reservations on, which is exactly where this can go
    # quietly wrong and oversell.
    it 'still subtracts a local checkout hold' do
      cart = create(:cart, store: store)
      line_item = create(:line_item, order: cart, variant: variant, quantity: 4)
      local_item = variant.stock_levels.reload.first
      create(:stock_reservation, stock_level: local_item, line_item: line_item, cart: cart, quantity: 4)

      quantifier = Spree::Stock::Quantifier.new(variant, stock_levels: external_rows(count_on_hand: 10))

      expect(quantifier.total_on_hand).to eq(6)
    end

    it 'leaves a cart its own hold when checking its own items' do
      cart = create(:cart, store: store)
      line_item = create(:line_item, order: cart, variant: variant, quantity: 4)
      local_item = variant.stock_levels.reload.first
      create(:stock_reservation, stock_level: local_item, line_item: line_item, cart: cart, quantity: 4)

      quantifier = Spree::Stock::Quantifier.new(
        variant, excluded_order: cart, stock_levels: external_rows(count_on_hand: 10)
      )

      expect(quantifier.total_on_hand).to eq(10)
    end
  end

  describe 'Internal provider rows' do
    let(:provider) { Spree::InventoryProvider::Internal.new }

    it 'returns the variant stock items' do
      expect(provider.stock_levels_for(variant).map(&:id)).to eq(variant.stock_levels.map(&:id))
    end

    it 'narrows to one location when asked' do
      other = create(:stock_location, store: store)
      create(:stock_level, variant: variant, stock_location: other, count_on_hand: 5, adjust_count_on_hand: false)
      variant.stock_levels.reload

      expect(provider.stock_levels_for(variant, stock_location: other).map(&:stock_location_id)).to eq([other.id])
    end

    it 'keeps a preloaded association in memory rather than querying again' do
      loaded = Spree::Variant.includes(:stock_levels).find(variant.id)

      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name].to_s.in?(['SCHEMA', 'TRANSACTION']) }

      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
        provider.stock_levels_for(loaded, stock_location: stock_location).to_a
      end

      expect(queries).to eq(0)
    end
  end

  describe 'an unknown provider key' do
    it 'falls back to Spree stock records rather than taking checkout down' do
      stub_store_preferences(store, inventory_provider: 'uninstalled_gem')

      expect(store.inventory_provider_instance).to be_a(Spree::InventoryProvider::Internal)
    end
  end
end
