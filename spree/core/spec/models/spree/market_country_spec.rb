require 'spec_helper'

RSpec.describe Spree::MarketCountry, type: :model do
  describe 'validations' do
    describe '#country_covered_by_shipping_zone' do
      let(:store) { create(:store) }
      let(:market) { create(:market, store: store) }

      context 'when country is in a zone with a shipping method' do
        let(:country) { create(:country) }
        let!(:zone) { create(:delivery_zone) }

        before do
          zone.members.create!(member_type: 'country', country_code: country.iso)
          create(:shipping_method, delivery_zone: zone)
        end

        it 'is valid' do
          market_country = Spree::MarketCountry.new(market: market, country_code: country.iso)
          expect(market_country).to be_valid
        end
      end

      context 'when country has no shipping zone coverage' do
        let(:country) { create(:country) }

        before do
          market # instantiate first — the factory may add a worldwide method
          # scope any worldwide methods (e.g. the market factory's) elsewhere
          elsewhere = create(:delivery_zone)
          elsewhere.members.create!(member_type: 'country', country_code: create(:country).iso)
          Spree::DeliveryMethod.find_each { |dm| dm.update!(delivery_zone: elsewhere) if dm.delivery_zone.nil? }
        end

        it 'is invalid' do
          market_country = Spree::MarketCountry.new(market: market, country_code: country.iso)
          expect(market_country).not_to be_valid
          expect(market_country.errors[:country]).to include(/not covered by any shipping zone/)
        end
      end

      context 'when country is in a zone without a shipping method' do
        let(:country) { create(:country) }
        let!(:zone) { create(:delivery_zone) }

        before do
          market # instantiate first — the factory may add a worldwide method
          zone.members.create!(member_type: 'country', country_code: country.iso)
          elsewhere = create(:delivery_zone)
          elsewhere.members.create!(member_type: 'country', country_code: create(:country).iso)
          Spree::DeliveryMethod.find_each { |dm| dm.update!(delivery_zone: elsewhere) if dm.delivery_zone.nil? }
        end

        it 'is invalid' do
          market_country = Spree::MarketCountry.new(market: market, country_code: country.iso)
          expect(market_country).not_to be_valid
          expect(market_country.errors[:country]).to include(/not covered by any shipping zone/)
        end
      end

      context 'when country is covered via a state-type zone' do
        let(:country) { create(:country) }
        let(:state) { create(:state, country: country) }
        let!(:zone) { create(:delivery_zone) }

        before do
          zone.members.create!(member_type: 'state', country_code: state.country_code, state_code: state.abbr)
          create(:shipping_method, delivery_zone: zone)
        end

        it 'is valid' do
          market_country = Spree::MarketCountry.new(market: market, country_code: country.iso)
          expect(market_country).to be_valid
        end
      end
    end

    describe '#country_unique_per_store' do
      let(:store) { create(:store) }
      let(:country) { create(:country) }
      let(:market1) { create(:market, store: store, countries: [country]) }

      it 'prevents assigning same country to another market in the same store' do
        market1 # ensure it exists
        market2 = create(:market, store: store)
        market_country = Spree::MarketCountry.new(market: market2, country_code: country.iso)
        expect(market_country).not_to be_valid
        expect(market_country.errors[:country]).to include(/already assigned to another market/)
      end

      it 'allows same country in markets of different stores' do
        market1 # ensure it exists
        other_store = create(:store)
        market2 = create(:market, store: other_store, countries: [country])
        expect(market2).to be_valid
      end
    end
  end
end
