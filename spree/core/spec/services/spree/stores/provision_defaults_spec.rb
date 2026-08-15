require 'spec_helper'

RSpec.describe Spree::Stores::ProvisionDefaults do
  subject { described_class.call(store: store, country: country, locale: locale) }

  let(:store) { create(:store) }
  let(:country) { Spree::Country.by_iso('DE') }
  let(:locale) { 'de' }

  describe 'the default market' do
    it 're-points the bootstrap market at the chosen country' do
      subject

      market = store.reload.default_market
      expect(market.country_codes).to eq(['DE'])
      expect(market.name).to eq('Germany')
      expect(market.currency).to eq('EUR')
      expect(market.default_locale).to eq('de')
    end

    # The market is authoritative for these readers, so this is what proves
    # the store actually presents as German rather than just storing 'DE'.
    it 'makes the store read as the chosen country' do
      subject

      store.reload
      expect(store.default_country_code).to eq('DE')
      expect(store.default_currency).to eq('EUR')
      expect(store.default_locale).to eq('de')
    end

    it 'does not create a second market' do
      expect { subject }.not_to change { store.reload.markets.count }
    end
  end

  describe 'the stock location' do
    it 'places the warehouse in the chosen country' do
      subject

      location = store.reload.stock_locations.find_by(default: true)
      expect(location.country_code).to eq('DE')
      expect(location).to be_active
    end
  end

  describe 'the delivery zones' do
    it 'makes Domestic mean the chosen country and International everywhere else' do
      subject

      domestic = store.reload.delivery_zones.find_by(name: 'Domestic')
      international = store.delivery_zones.find_by(name: 'International')

      expect(domestic.members.pluck(:country_code)).to eq(['DE'])
      expect(domestic.description).to eq('Germany')
      expect(international.members.where(country_code: 'DE')).not_to exist
      expect(international.members.where(country_code: 'US')).to exist
    end

    it 'prices the flat rates in the country currency' do
      subject

      store.reload
      expect(store.delivery_methods.find_by(name: 'Standard').calculator.preferred_currency).to eq('EUR')
      expect(store.delivery_methods.find_by(name: 'International Shipping').calculator.preferred_currency).to eq('EUR')
    end
  end

  describe 'pickup' do
    it 'opens the default location for collection and prices pickup in the country currency' do
      subject

      store.reload
      expect(store.stock_locations.where(pickup_enabled: true)).to exist

      pickup = store.delivery_methods.find_by(name: Spree.t('pickup.store_pickup'))
      expect(pickup.fulfillment_provider).to eq('Spree::FulfillmentProvider::Pickup')
      expect(pickup.calculator.preferred_currency).to eq('EUR')
    end
  end

  describe 'currency and locale derivation' do
    context 'when no locale is given' do
      let(:locale) { nil }

      it "falls back to the country's own language" do
        subject

        expect(store.reload.default_market.default_locale).to eq('de')
      end
    end

    context 'for a country with several official languages' do
      let(:country) { Spree::Country.by_iso('CH') }
      let(:locale) { 'fr' }

      it 'derives the currency from the country and honors the chosen locale' do
        subject

        market = store.reload.default_market
        expect(market.currency).to eq('CHF')
        expect(market.default_locale).to eq('fr')
      end
    end
  end

  describe 'running twice' do
    it 'is idempotent' do
      subject

      expect { described_class.call(store: store, country: country, locale: locale) }.
        not_to change { store.reload.delivery_methods.count }
    end

    # Re-provisioning has to rewrite zone membership, not add to it, or the
    # previous country is left behind on both zones.
    it 'moves the previous country out of Domestic when the country changes' do
      subject

      described_class.call(store: store, country: Spree::Country.by_iso('CH'), locale: 'fr')

      domestic = store.reload.delivery_zones.find_by(name: 'Domestic')
      international = store.delivery_zones.find_by(name: 'International')

      expect(domestic.members.pluck(:country_code)).to eq(['CH'])
      expect(international.members.where(country_code: 'DE')).to exist
      expect(international.members.where(country_code: 'CH')).not_to exist
    end
  end
end
