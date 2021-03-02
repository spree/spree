require 'spec_helper'

describe Spree::AddressesHelper, type: :helper do
  class SampleClass
    include Spree::AddressesHelper
  end

  describe '#user_available_addresses' do
    subject        { SampleClass.new.user_available_addresses }

    let!(:user)    { create(:user) }
    let!(:store)   { create(:store) }

    let(:new_york) { create(:state, name: 'New York') }

    # countries
    let!(:united_states) do
      create(:country, name: 'United States').tap do |usa|
        usa.states << new_york
      end
    end
    let!(:china)   { create(:country, name: 'China') }
    let!(:ukraine) { create(:country, name: 'Ukraine') }

    # addresses
    let!(:usa_address) do
      create(:address,
             country_id: united_states.id,
             state_id: new_york.id,
             user: user)
    end
    let!(:china_address) do
      create(:address,
             country_id: china.id,
             user: user)
    end
    let!(:ukraine_address) do
      create(:address,
             country_id: ukraine.id,
             user: user)
    end

    before do
      allow_any_instance_of(described_class).to receive(:current_store)          { store }
      allow_any_instance_of(described_class).to receive(:try_spree_current_user) { current_store }
    end

    context 'when user is not present' do
      let(:current_store) { nil }

      it 'returns an empty array' do
        expect(subject).to match_array []
      end
    end

    context 'when user is present' do
      let(:current_store) { user }

      before do
        store.update(checkout_zone: checkout_zone)
      end

      context 'when checkout zone does not include user addresses states' do
        let(:checkout_zone) { create(:zone, kind: :country) } # zone with no attached zoneable

        it 'returns an empty array' do
          expect(subject).to match_array []
        end
      end

      context 'when checkout zone includes user addresses states' do # Global Zone including all countries
        let(:checkout_zone) { create(:global_zone) }

        it 'returns that addresses' do
          expect(subject).to contain_exactly(usa_address)
        end
      end
    end
  end
end
