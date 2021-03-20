require 'spec_helper'

describe Spree::CountryHelper, type: :helper do
  let!(:germany) { create(:country, name: 'Germany', iso: 'DE') }
  let!(:france) { create(:country, name: 'France', iso: 'FR') }
  let!(:italy) { create(:country, name: 'Italy', iso: 'IT') }
  let!(:russia) { create(:country, name: 'Russia', iso: 'RU') }
  let!(:uk) { create(:country, name: 'UK', iso: 'GB') }

  let(:eu_store) { create(:store, default_currency: 'EUR', default_locale: 'en', default_country: germany, supported_locales: 'fr,de,it,en') }
  let(:available_locales) { Spree::Store.available_locales }
  let(:supported_locales_for_all_stores) { [:en, :de, :fr, :it] }

  let(:current_locale) { I18n.locale }
  let(:current_store) { eu_store }

  before do
    I18n.backend.store_translations(:en,
                                    spree: {
                                      country_name_overide: {
                                        ru: 'RUSSSIA - RU'
                                      }
                                    })
  end

  describe '#all_country_options' do
    it { expect(all_country_options).to contain_exactly(["France", france.id], ["Germany", germany.id], ["Italy", italy.id], ["RUSSSIA - RU", russia.id], ["United Kingdom", uk.id]) }
  end

  describe '#country_presentation in English returns' do
    it { expect(country_presentation(france)).to eq(['France', france.id]) }
  end

  describe '#country_presentation in German' do
    let(:current_locale) { :de }

    it { expect(country_presentation(france)).to eq(['Frankreich', france.id]) }
  end

  describe '#localized_country_name in English' do
    context 'to return Germany' do
      it { expect(localized_country_name('DE')).to eq('Germany') }
    end
  end

  describe '#localized_country_name in French' do
    let(:current_locale) { :fr }

    context 'to return DE name as Germany in emglish' do
      it { expect(localized_country_name('DE')).to eq('Allemagne') }
    end
  end

  context 'available_countries' do
    let(:country) { create(:country, name: 'United States', iso: 'US') }
    let(:country_1) { create(:country, name: 'Germany', iso: 'DE') }
    let(:country_2) { create(:country, name: 'England', iso: 'GB') }
    let(:country_3) { create(:country, name: 'France', iso: 'FR') }

    context 'with checkout zone assigned to the store' do
      before do
        Spree::Config[:checkout_zone] = nil
        @zone = create(:zone, name: 'No Limits', kind: 'country')
        @zone.members.create(zoneable: country)
        current_store.update(checkout_zone_id: @zone.id)
      end

      it 'return only the countries defined by the checkout_zone_id' do
        expect(available_countries).to eq([country])
        expect(current_store.checkout_zone_id).to eq @zone.id
      end
    end

    context 'with no checkout zone defined' do
      before do
        Spree::Config[:checkout_zone] = nil
        current_store.update(checkout_zone_id: nil)
      end

      it 'return complete list of countries' do
        expect(available_countries.count).to eq(Spree::Country.count)
      end
    end

    context 'with a checkout zone defined' do
      context 'checkout zone is of type country' do
        before do
          @country_zone = create(:zone, name: 'CountryZone', kind: 'country')
          @country_zone.members.create(zoneable: country)
          Spree::Config[:checkout_zone] = @country_zone.name
        end

        it 'return only the countries defined by the checkout zone' do
          expect(available_countries).to eq([country])
        end
      end

      context 'checkout zone is of type state' do
        let(:state) { create(:state, country: country) }

        before do
          state_zone = create(:zone, name: 'StateZone')
          state_zone.members.create(zoneable: state)

          Spree::Config[:checkout_zone] = state_zone.name
        end

        it 'returns list of countries associated with states' do
          expect(available_countries).to contain_exactly state.country
        end
      end
    end
  end
end
