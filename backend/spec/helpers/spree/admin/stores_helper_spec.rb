require 'spec_helper'

describe Spree::Admin::StoresHelper, type: :helper do

  describe '#selected_checkout_zone' do
    let!(:store) { create(:store) }
    let!(:country) { create(:country) }
    let!(:country_zone) { create(:zone, name: 'CountryZone') }

    context 'with set preference checkout_zone in spree config file' do
      before do
        country_zone.members.create(zoneable: country)
        Spree::Config[:checkout_zone] = country_zone.name
      end

      it 'return countries' do
        expect(selected_checkout_zone(store)).to eq Spree::Zone.find_by(name: Spree::Config[:checkout_zone])
      end
    end

    context 'with checkout_zone_id set on store' do
      before do
        Spree::Config.preference_default(:checkout_zone)
        country_zone.members.create(zoneable: country)
        store.update(checkout_zone_id: country_zone.id)
      end

      it 'return countries' do
        expect(selected_checkout_zone(store)).to eq country_zone
      end
    end

    context 'checkout_zone is not set via preference or store' do
      before do
        Spree::Config.preference_default(:checkout_zone)
        store.update(checkout_zone_id: nil)
      end

      it 'return nil' do
        expect(selected_checkout_zone(store)).to eq nil
      end
    end
  end
end
