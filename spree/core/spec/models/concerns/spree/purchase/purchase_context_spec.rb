require 'spec_helper'

# Channel/Market/Currency/Locale are one cohesive resolution surface —
# batteried together, against both hosts.
RSpec.shared_examples 'a channel host' do
  let(:store) { @default_store }

  describe '#ensure_channel_presence' do
    it 'auto-assigns the store default channel on new records' do
      record = new_record(channel: nil)
      record.valid?

      expect(record.channel).to eq(store.default_channel)
    end

    it 'preserves an explicitly set channel' do
      other = store.channels.find_by(code: 'pos') || store.channels.create!(name: 'POS', code: 'pos')
      record = new_record(channel: other)
      record.valid?

      expect(record.channel).to eq(other)
    end
  end
end

RSpec.shared_examples 'a market host' do
  let(:store) { @default_store }

  describe '#ensure_market_presence' do
    it 'auto-assigns the store default market on new records' do
      record = new_record
      record.valid?

      expect(record.market).to eq(store.default_market)
    end
  end

  describe '#resolve_market_from_currency' do
    let!(:eur_market) do
      germany = Spree::Country.find_by(iso: 'DE') || create(:country, iso: 'DE')
      store.markets.find_by(currency: 'EUR') ||
        store.markets.create!(name: 'Europe', currency: 'EUR', default_locale: 'de', countries: [germany])
    end

    it 'switches to the market matching the new currency on update' do
      record = new_record.tap(&:save!)
      record.update(currency: 'EUR')

      expect(record.market).to eq(eur_market)
    end

    it 'keeps the current market when no market serves the currency' do
      record = new_record.tap(&:save!)

      expect { record.update(currency: 'GBP') }.not_to change(record, :market)
    end
  end
end

RSpec.shared_examples 'a currency host' do
  describe '#ensure_currency' do
    it 'fills a blank currency from the market' do
      record = new_record
      record.currency = nil
      record.valid?

      expect(record.currency).to eq(record.market.currency)
    end
  end

  describe '#currency_must_be_supported_by_store' do
    it 'rejects a currency the store does not support' do
      record = new_record
      record.currency = 'XOF'

      expect(record).not_to be_valid
      expect(record.errors[:currency]).to be_present
    end
  end
end

RSpec.shared_examples 'a locale host' do
  describe '#ensure_locale' do
    it 'fills a blank locale from the current locale or market default' do
      record = new_record
      record.locale = nil
      record.valid?

      expect(record.locale).to be_present
    end
  end

  describe '#locale_must_be_supported_by_store' do
    it 'rejects a locale the store does not support' do
      record = new_record
      record.locale = 'xx'

      expect(record).not_to be_valid
      expect(record.errors[:locale]).to be_present
    end
  end
end

RSpec.describe 'Spree::Purchase context concerns' do
  context 'included in Spree::Cart' do
    def new_record(**attributes)
      build(:cart, store: @default_store, **attributes)
    end

    it_behaves_like 'a channel host'
    it_behaves_like 'a market host'
    it_behaves_like 'a currency host'
    it_behaves_like 'a locale host'
  end

  context 'included in Spree::Order' do
    def new_record(**attributes)
      build(:order, store: @default_store, **attributes)
    end

    it_behaves_like 'a channel host'
    it_behaves_like 'a market host'
    it_behaves_like 'a currency host'
    it_behaves_like 'a locale host'
  end
end
