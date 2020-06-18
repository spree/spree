require 'spec_helper'

describe Spree::AddressesHelper, type: :helper do
  describe '#user_available_addresses' do
    let!(:user) { create(:user) }

    let!(:united_states) { create(:country, name: 'United States') }
    let!(:poland)        { create(:country, name: 'Poland') }
    let!(:china)         { create(:country, name: 'China') }
    let!(:ukraine)       { create(:country, name: 'Ukraine') }

    let!(:address_1) { create(:address, country_id: united_states.id, state_id: united_states.states.first, user: user) }
    let!(:address_2) { create(:address, country_id: poland.id, state_id: poland.states.first, user: user) }
    let!(:address_3) { create(:address, country_id: china.id, state_id: china.states.first, user: user) }
    
    context 'when user is present' do
      subject { user_available_addresses }

      context 'when available countries do not includes user addresses countries' do
        it 'returns an empty array' do
          allow_any_instance_of(Spree::AddressesHelper).to receive(:try_spree_current_user).and_return(user)
          allow_any_instance_of(Spree::AddressesHelper).to receive(:available_countries).and_return([ukraine])

          expect(subject).to match_array []
        end
      end

      context 'when available countries includes user addresses countries' do
        it 'returns that addresses' do
          allow_any_instance_of(Spree::AddressesHelper).to receive(:try_spree_current_user).and_return(user)
          allow_any_instance_of(Spree::AddressesHelper).to receive(:available_countries).and_return([poland, united_states])

          expect(subject).to match_array [address_1, address_2]
        end
      end
    end

    context 'when user is absent' do
      subject { user_available_addresses }

      it 'returns nil' do
        allow_any_instance_of(Spree::AddressesHelper).to receive(:try_spree_current_user).and_return(nil)

        expect(subject).to eq nil
      end
    end
  end
end
