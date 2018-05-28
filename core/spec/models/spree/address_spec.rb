require 'spec_helper'

describe Spree::Address, type: :model do
  describe 'clone' do
    it 'creates a copy of the address with the exception of the id, updated_at and created_at attributes' do
      state = create(:state)
      original = create(:address,
                        address1: 'address1',
                        address2: 'address2',
                        alternative_phone: 'alternative_phone',
                        city: 'city',
                        country: Spree::Country.first,
                        firstname: 'firstname',
                        lastname: 'lastname',
                        company: 'company',
                        phone: 'phone',
                        state_id: state.id,
                        state_name: state.name,
                        zipcode: '10001')

      cloned = original.clone

      expect(cloned.address1).to eq(original.address1)
      expect(cloned.address2).to eq(original.address2)
      expect(cloned.alternative_phone).to eq(original.alternative_phone)
      expect(cloned.city).to eq(original.city)
      expect(cloned.country_id).to eq(original.country_id)
      expect(cloned.firstname).to eq(original.firstname)
      expect(cloned.lastname).to eq(original.lastname)
      expect(cloned.company).to eq(original.company)
      expect(cloned.phone).to eq(original.phone)
      expect(cloned.state_id).to eq(original.state_id)
      expect(cloned.state_name).to eq(original.state_name)
      expect(cloned.zipcode).to eq(original.zipcode)

      expect(cloned.id).not_to eq(original.id)
      expect(cloned.created_at).not_to eq(original.created_at)
      expect(cloned.updated_at).not_to eq(original.updated_at)
    end
  end

  context 'aliased attributes' do
    let(:address) { Spree::Address.new }

    it 'first_name' do
      address.firstname = 'Ryan'
      expect(address.first_name).to eq('Ryan')
    end

    it 'last_name' do
      address.lastname = 'Bigg'
      expect(address.last_name).to eq('Bigg')
    end
  end

  context 'validation' do
    let(:country) { stub_model(Spree::Country, states: [state], states_required: true) }
    let(:state) { stub_model(Spree::State, name: 'maryland', abbr: 'md') }
    let(:address) { build(:address, country: country) }

    before do
      allow(Spree::State).to receive(:find_all_by_name_or_abbr) { [state] }

      configure_spree_preferences do |config|
        config.address_requires_state = true
      end
    end

    it 'state_name is not nil and country does not have any states' do
      address.state = nil
      address.state_name = 'alabama'
      expect(address).to be_valid
    end

    it 'errors when state_name is nil' do
      address.state_name = nil
      address.state = nil
      expect(address).not_to be_valid
    end

    it 'full state name is in state_name and country does contain that state' do
      address.state_name = 'alabama'
      # called by state_validate to set up state_id.
      # Perhaps this should be a before_validation instead?
      expect(address).to be_valid
      expect(address.state).not_to be_nil
      expect(address.state_name).to be_nil
    end

    it 'state abbr is in state_name and country does contain that state' do
      address.state_name = state.abbr
      expect(address).to be_valid
      expect(address.state_id).not_to be_nil
      expect(address.state_name).to be_nil
    end

    it 'state is entered but country does not contain that state' do
      address.state = state
      address.country = stub_model(Spree::Country, states_required: true)
      address.valid?
      expect(address.errors['state']).to eq(['is invalid'])
    end

    it 'both state and state_name are entered but country does not contain the state' do
      address.state = state
      address.state_name = 'maryland'
      address.country = stub_model(Spree::Country, states_required: true)
      expect(address).to be_valid
      expect(address.state_id).to be_nil
    end

    it 'both state and state_name are entered and country does contain the state' do
      address.state = state
      address.state_name = 'maryland'
      expect(address).to be_valid
      expect(address.state_name).to be_nil
    end

    it 'address_requires_state preference is false' do
      Spree::Config.set address_requires_state: false
      address.state = nil
      address.state_name = nil
      expect(address).to be_valid
    end

    it 'requires phone' do
      address.phone = ''
      address.valid?
      expect(address.errors['phone']).to eq(["can't be blank"])
    end

    it 'requires zipcode' do
      address.zipcode = ''
      address.valid?
      expect(address.errors['zipcode']).to include("can't be blank")
    end

    context 'zipcode validation' do
      it 'validates the zipcode' do
        allow(address.country).to receive(:iso).and_return('US')
        address.zipcode = 'abc'
        address.valid?
        expect(address.errors['zipcode']).to include('is invalid')
      end

      it 'accepts a zip code with surrounding white space' do
        allow(address.country).to receive(:iso).and_return('US')
        address.zipcode = ' 12345 '
        address.valid?
        expect(address.errors['zipcode']).not_to include('is invalid')
      end

      context 'does not validate' do
        it 'does not have a country' do
          address.country = nil
          address.valid?
          expect(address.errors['zipcode']).not_to include('is invalid')
        end

        it 'country does not requires zipcode' do
          allow(address.country).to receive(:zipcode_required?).and_return(false)
          address.valid?
          expect(address.errors['zipcode']).not_to include('is invalid')
        end

        it 'does not have an iso' do
          allow(address.country).to receive(:iso).and_return(nil)
          address.valid?
          expect(address.errors['zipcode']).not_to include('is invalid')
        end

        it 'does not have a zipcode' do
          address.zipcode = ''
          address.valid?
          expect(address.errors['zipcode']).not_to include('is invalid')
        end

        it 'does not have a supported country iso' do
          allow(address.country).to receive(:iso).and_return('BO')
          address.valid?
          expect(address.errors['zipcode']).not_to include('is invalid')
        end
      end
    end

    context 'phone not required' do
      before { allow(address).to receive_messages require_phone?: false }

      it 'shows no errors when phone is blank' do
        address.phone = ''
        address.valid?
        expect(address.errors[:phone].size).to eq 0
      end
    end

    context 'zipcode not required' do
      before { allow(address).to receive_messages require_zipcode?: false }

      it 'shows no errors when phone is blank' do
        address.zipcode = ''
        address.valid?
        expect(address.errors[:zipcode].size).to eq 0
      end
    end
  end

  context '.default' do
    context 'no user given' do
      before do
        @default_country_id = Spree::Config[:default_country_id]
        new_country = create(:country)
        Spree::Config[:default_country_id] = new_country.id
      end

      after do
        Spree::Config[:default_country_id] = @default_country_id
      end

      it 'sets up a new record with Spree::Config[:default_country_id]' do
        expect(Spree::Address.default.country).to eq(Spree::Country.find(Spree::Config[:default_country_id]))
      end

      # Regression test for #1142
      it 'uses the first available country if :default_country_id is set to an invalid value' do
        Spree::Config[:default_country_id] = '0'
        expect(Spree::Address.default.country).to eq(Spree::Country.first)
      end
    end

    context 'user given' do
      let(:bill_address) { Spree::Address.new(phone: Time.current.to_i) }
      let(:ship_address) { double('ShipAddress') }
      let(:user) { double('User', bill_address: bill_address, ship_address: ship_address) }

      it 'returns a copy of that user bill address' do
        expect(Spree::Address.default(user).phone).to eq bill_address.phone
      end

      it 'falls back to build default when user has no address' do
        allow(user).to receive_messages(bill_address: nil)
        expect(Spree::Address.default(user)).to eq Spree::Address.build_default
      end
    end
  end

  context '#full_name' do
    context 'both first and last names are present' do
      let(:address) { stub_model(Spree::Address, firstname: 'Michael', lastname: 'Jackson') }

      specify { expect(address.full_name).to eq('Michael Jackson') }
    end

    context 'first name is blank' do
      let(:address) { stub_model(Spree::Address, firstname: nil, lastname: 'Jackson') }

      specify { expect(address.full_name).to eq('Jackson') }
    end

    context 'last name is blank' do
      let(:address) { stub_model(Spree::Address, firstname: 'Michael', lastname: nil) }

      specify { expect(address.full_name).to eq('Michael') }
    end

    context 'both first and last names are blank' do
      let(:address) { stub_model(Spree::Address, firstname: nil, lastname: nil) }

      specify { expect(address.full_name).to eq('') }
    end
  end

  context '#state_text' do
    context 'state is blank' do
      let(:address) { stub_model(Spree::Address, state: nil, state_name: 'virginia') }

      specify { expect(address.state_text).to eq('virginia') }
    end

    context 'both name and abbr is present' do
      let(:state) { stub_model(Spree::State, name: 'virginia', abbr: 'va') }
      let(:address) { stub_model(Spree::Address, state: state) }

      specify { expect(address.state_text).to eq('va') }
    end

    context 'only name is present' do
      let(:state) { stub_model(Spree::State, name: 'virginia', abbr: nil) }
      let(:address) { stub_model(Spree::Address, state: state) }

      specify { expect(address.state_text).to eq('virginia') }
    end
  end

  context 'defines require_phone? helper method' do
    let(:address) { stub_model(Spree::Address) }

    specify { expect(address.instance_eval { require_phone? }).to be true }
  end

  context '#clear_state' do
    let (:address) { create(:address) }

    before { address.state_name = 'maryland' }

    it { expect { address.send(:clear_state) }.to change(address, :state).to(nil).from(address.state) }
    it { expect { address.send(:clear_state) }.not_to change(address, :state_name) }
  end

  context '#clear_state_name' do
    let (:address) { create(:address) }

    before { address.state_name = 'maryland' }

    it { expect { address.send(:clear_state_name) }.not_to change(address, :state_id) }
    it { expect { address.send(:clear_state_name) }.to change(address, :state_name).to(nil).from('maryland') }
  end

  context '#clear_invalid_state_entities' do
    let(:country) { create(:country) }
    let(:state) { create(:state, country: country) }
    let (:address) { create(:address, country: country, state: state) }

    def clear_state_entities
      address.send(:clear_invalid_state_entities)
    end

    context 'state not present and state_name both not present' do
      before do
        address.state = nil
        address.state_name = nil
        clear_state_entities
      end

      it { expect(address.state).to be_nil }
      it { expect(address.state_name).to be_nil }
    end

    context 'state_name not present and state present ' do
      before { address.state_name = nil }

      context 'state belongs to a different country than to which address is associated' do
        before do
          address.country = create(:country)
          clear_state_entities
        end

        it { expect(address.state).to be_nil }
        it { expect(address.state_name).to be_nil }
      end

      context 'state belongs to the same country associated with address' do
        before { clear_state_entities }
        it { expect(address.state).to eq(state) }
        it { expect(address.state_name).to be_nil }
      end
    end

    context 'state not present and state_name present' do
      before do
        address.state = nil
        address.state_name = state.name
      end

      context 'when country has no states and state is required' do
        before do
          address.country = create(:country, states_required: true)
          clear_state_entities
        end

        it { expect(address.state).to be_nil }
        it { expect(address.state_name).to eq(state.name) }
      end

      context 'when country has states' do
        before do
          address.state_name = state.name
          clear_state_entities
        end

        it { expect(address.state).to be_nil }
        it { expect(address.state_name).to eq(state.name) }
      end

      context 'when country has no states and state is not required' do
        before do
          address.country = create(:country, states_required: false)
          address.state_name = state.name
          clear_state_entities
        end

        it { expect(address.state).to be_nil }
        it { expect(address.state_name).to be_nil }
      end
    end
  end

  context '#same_as' do
    let(:address) { create(:address) }
    let(:address2) { address.clone }

    context 'same addresses' do
      it { expect(address.same_as?(address2)).to eq(true) }
    end

    context 'different addresses' do
      before { address2.first_name = 'Someone Else' }
      it { expect(address.same_as?(address2)).to eq(false) }
    end
  end

  describe '.build_default' do
    let(:_address) { described_class.build_default }

    it { expect(_address.country).to eq(Spree::Country.default) }
  end
end
