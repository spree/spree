require 'spec_helper'

RSpec.describe Spree::Products::ReadinessCheck do
  # `Store` auto-creates its own default channel (see
  # `Spree::Stores::Channels#ensure_default_channel`) — reuse it instead of
  # creating a second channel the product factory won't auto-publish to.
  let(:store) { create(:store) }
  let(:channel) { store.default_channel }
  let!(:market) { create(:market, store: store, currency: 'USD', default_locale: 'en') }
  let(:product) { create(:product, store: store) }

  before { channel }

  describe '.call' do
    it 'is ready when status, publication, price, stock, and translation all check out' do
      result = described_class.call(product: product)

      expect(result).to be_ready
      expect(result.checks).to all(be_ready)
    end

    it 'flags a non-active status' do
      product.update_column(:status, 'archived')

      result = described_class.call(product: product)

      expect(result).not_to be_ready
      status_check = result.checks.find { |c| c.key == 'status' }
      expect(status_check).not_to be_ready
      expect(status_check.message).to match(/archived/)
    end

    it 'flags a channel the product is not published to' do
      other_channel = create(:channel, store: store, code: 'pos', name: 'Point of Sale', active: true)

      result = described_class.call(product: product)

      expect(result).not_to be_ready
      channel_check = result.checks.find { |c| c.key == "channel:#{other_channel.code}" }
      expect(channel_check).not_to be_ready
      expect(channel_check.message).to include('Point of Sale')
    end

    it 'flags a market currency with no price' do
      eur_market = create(:market, store: store, currency: 'EUR', default_locale: 'en')

      result = described_class.call(product: product)

      expect(result).not_to be_ready
      price_check = result.checks.find { |c| c.key == 'price:EUR' }
      expect(price_check).not_to be_ready
      expect(price_check.message).to match(/EUR/)
      expect(price_check.message).to include(eur_market.name)
    end

    it 'flags a product with no purchasable variant' do
      product.master.stock_items.update_all(count_on_hand: 0, backorderable: false)
      product.master.update_column(:track_inventory, true)

      result = described_class.call(product: product)

      expect(result).not_to be_ready
      stock_check = result.checks.find { |c| c.key == 'stock' }
      expect(stock_check).not_to be_ready
    end

    it 'flags a market locale the product has no translation for' do
      create(:market, store: store, currency: 'USD', default_locale: 'pl', name: 'Polska')

      result = described_class.call(product: product)

      expect(result).not_to be_ready
      translation_check = result.checks.find { |c| c.key == 'translation:pl' }
      expect(translation_check).not_to be_ready
    end
  end
end
