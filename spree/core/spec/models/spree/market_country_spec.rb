require 'spec_helper'

RSpec.describe Spree::MarketCountry, type: :model do
  describe 'validations' do
    describe '#country_covered_by_shipping_zone' do
      let(:store) { create(:store) }
      let(:market) { create(:market, store: store) }

      context 'when country is in a zone with a shipping method' do
        let(:country) { create(:country) }
        let!(:zone) { create(:zone, kind: 'country') }

        before do
          zone.zone_members.create!(zoneable: country)
          create(:shipping_method, zones: [zone])
        end

        it 'is valid' do
          market_country = Spree::MarketCountry.new(market: market, country: country)
          expect(market_country).to be_valid
        end
      end

      context 'when country has no shipping zone coverage' do
        let(:country) { create(:country) }

        it 'is invalid' do
          market_country = Spree::MarketCountry.new(market: market, country: country)
          expect(market_country).not_to be_valid
          expect(market_country.errors[:country]).to include(/not covered by any shipping zone/)
        end
      end

      context 'when country is in a zone without a shipping method' do
        let(:country) { create(:country) }
        let!(:zone) { create(:zone, kind: 'country') }

        before do
          zone.zone_members.create!(zoneable: country)
        end

        it 'is invalid' do
          market_country = Spree::MarketCountry.new(market: market, country: country)
          expect(market_country).not_to be_valid
          expect(market_country.errors[:country]).to include(/not covered by any shipping zone/)
        end
      end

      context 'when country is covered via a state-type zone' do
        let(:country) { create(:country) }
        let(:state) { create(:state, country: country) }
        let!(:zone) { create(:zone, kind: 'state') }

        before do
          zone.zone_members.create!(zoneable: state)
          create(:shipping_method, zones: [zone])
        end

        it 'is valid' do
          market_country = Spree::MarketCountry.new(market: market, country: country)
          expect(market_country).to be_valid
        end
      end
    end
  end
end
