require 'spec_helper'

describe Spree::AddressesHelper, type: :helper do
  describe '#user_available_addresses' do
    subject { user_available_addresses }

    let!(:store)  { create(:store) }
    let!(:user)   { create(:user) }

    let!(:united_states) { create(:country, name: 'United States') }
    let!(:poland)        { create(:country, name: 'Poland') }
    let!(:china)         { create(:country, name: 'China') }
    let!(:ukraine)       { create(:country, name: 'Ukraine') }

    let!(:address_1) { create(:address, country_id: united_states.id, user: user) }
    let!(:address_2) { create(:address, country_id: poland.id, user: user) }
    let!(:address_3) { create(:address, country_id: china.id, user: user) }

    before do
      allow_any_instance_of(described_class).to receive(:current_store).and_return(store)
    end

    context 'when user is present' do
      before do
        allow_any_instance_of(described_class).to receive(:try_spree_current_user).and_return(user)
      end

      context 'when checkout zone do not includes user addresses states' do
        before do
          store.update(checkout_zone: create(:zone))
        end

        it 'returns an empty array' do
          expect(subject).to match_array []
        end
      end

      context 'when checkout zone includes user addresses states' do # Global Zone
        before do
          state = create(:state, name: 'New York')

          united_states.states << state
          address_1.update(state: state)
        end

        it 'returns that addresses' do
          expect(subject).to match_array address_1
        end
      end
    end

    context 'when user is absent' do
      before do
        allow_any_instance_of(described_class).to receive(:try_spree_current_user).and_return(nil)
      end

      it 'returns an empty array' do
        expect(subject).to match_array []
      end
    end
  end
end
