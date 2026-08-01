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
    let(:store) { @default_store }

    before do
      allow(store).to receive(:supported_currencies).and_return(['EUR', 'USD'])
    end

    it 'is valid when the currency is supported by the store' do
      expect(new_record(currency: 'EUR')).to be_valid
    end

    it 'is invalid when the currency is not supported by the store' do
      record = new_record(currency: 'JPY')

      expect(record).not_to be_valid
      expect(record.errors[:currency]).to include(Spree.t(:currency_not_supported_by_store))
    end
  end
end

RSpec.shared_examples 'a locale host' do
  let(:store) { @default_store }

  describe '#ensure_locale' do
    it 'sets locale from Spree::Current.locale when blank' do
      allow(Spree::Current).to receive(:locale).and_return('fr')
      allow(store).to receive(:supported_locales_list).and_return(['en', 'fr'])

      record = new_record(locale: nil)
      record.valid?

      expect(record.locale).to eq('fr')
    end

    it 'does not override locale when already set' do
      allow(Spree::Current).to receive(:locale).and_return('fr')

      record = new_record(locale: 'en')
      record.valid?

      expect(record.locale).to eq('en')
    end
  end

  describe '#locale_must_be_supported_by_store' do
    before do
      allow(store).to receive(:supported_locales_list).and_return(['en', 'fr'])
    end

    it 'is valid when the locale is supported by the store' do
      expect(new_record(locale: 'fr')).to be_valid
    end

    it 'is invalid when the locale is not supported by the store' do
      record = new_record(locale: 'de')

      expect(record).not_to be_valid
      expect(record.errors[:locale]).to include(Spree.t(:locale_not_supported_by_store))
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
