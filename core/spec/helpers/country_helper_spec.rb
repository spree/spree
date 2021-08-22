require 'spec_helper'

describe Spree::CountryHelper, type: :helper do
  include described_class

  let(:current_store) { create :store }

  before do
    allow(controller).to receive(:controller_name).and_return('test')
    allow_any_instance_of(Spree::CountryHelper).to receive(:current_locale).and_return('en')
  end

  context 'available_countries' do
    let(:country) { create(:country) }

    before do
      create_list(:country, 3)
    end

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
