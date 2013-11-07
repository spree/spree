require 'spec_helper'

describe Spree::Address do
  describe 'association' do
    it { should belong_to(:country) }
    it { should belong_to(:state) }
    it { should have_many(:shipments) }
  end

  describe 'validation' do
    it { should validate_presence_of(:firstname) }
    it { should validate_presence_of(:lastname) }
    it { should validate_presence_of(:address1) }
    it { should validate_presence_of(:city) }
    it { should validate_presence_of(:country) }

    describe '#zipcode' do
      subject { stub_model(Spree::Address, require_zipcode?: true) }
      it { should validate_presence_of(:zipcode) }
    end

    describe '#phone' do
      subject { stub_model(Spree::Address, require_phone?: true) }
      it { should validate_presence_of(:phone) }
    end

    describe '#state_validate' do
      before do
        configure_spree_preferences do |config|
          config.address_requires_state = true
        end
      end

      let(:country) { mock_model(Spree::Country, states: [state], states_required: true) }
      let(:state) { stub_model(Spree::State, name: 'maryland', abbr: 'md') }
      let(:address) { build(:address, country: country) }

      before { country.states.stub find_all_by_name_or_abbr: [state] }

      context 'state_name is not nil and country does not have any states' do
        before do
          address.state = nil
          address.state_name = 'alabama'
        end
        specify { address.should be_valid }
      end

      context 'state_name is nil' do
        before do
          address.state_name = nil
          address.state = nil
        end
        specify { address.should_not be_valid }
      end

      context 'full state name is in state_name and country does contain that state' do
        before { address.state_name = 'alabama' }
        specify do
          # called by state_validate to set up state_id.
          # Perhaps this should be a before_validation instead?
          address.should be_valid
          address.state.should_not be_nil
          address.state_name.should be_nil
        end
      end

      context 'state abbr is in state_name and country does contain that state' do
        before { address.state_name = state.abbr }
        specify do
          address.should be_valid
          address.state_id.should_not be_nil
          address.state_name.should be_nil
        end
      end

      context 'state is entered but country does not contain that state' do
        before do
          address.state = state
          address.country = stub_model(Spree::Country, states_required: true)
        end
        specify { address.state.should be_invalid }
      end

      context 'both state and state_name are entered but country does not contain the state' do
        before do
          address.state = state
          address.state_name = 'maryland'
          address.country = stub_model(Spree::Country, states_required: true)
        end
        specify do
          address.should be_valid
          address.state_id.should be_nil
        end
      end

      context 'both state and state_name are entered and country does contain the state' do
        before do
          address.state = state
          address.state_name = 'maryland'
        end
        specify do
          address.should be_valid
          address.state_name.should be_nil
        end
      end

      context 'address_requires_state preference is false' do
        before do
          Spree::Config.set address_requires_state: false
          address.state = nil
          address.state_name = nil
        end
        specify { address.should be_valid }
      end
    end
  end

  describe '#clone' do
    let(:state) { create(:state) }
    let(:original) { create(:address,
      address1:   'address1',
      address2:   'address2',
      alternative_phone: 'alternative_phone',
      city:       'city',
      country:    create(:country),
      firstname:  'firstname',
      lastname:   'lastname',
      company:    'company',
      phone:      'phone',
      state_id:   state.id,
      state_name: state.name,
      zipcode:    'zip_code')
    }

    it 'creates a copy of the address with the exception of the id, updated_at and created_at attributes' do
      cloned = original.clone

      expect(cloned.address1).to be == original.address1
      expect(cloned.address2).to be == original.address2
      expect(cloned.alternative_phone).to be == original.alternative_phone
      expect(cloned.city).to be == original.city
      expect(cloned.country_id).to be == original.country_id
      expect(cloned.firstname).to be == original.firstname
      expect(cloned.lastname).to be == original.lastname
      expect(cloned.company).to be == original.company
      expect(cloned.phone).to be == original.phone
      expect(cloned.state_id).to be == original.state_id
      expect(cloned.state_name).to be == original.state_name
      expect(cloned.zipcode).to be == original.zipcode

      expect(cloned.id).not_to be == original.id
      expect(cloned.created_at).not_to be == original.created_at
      expect(cloned.updated_at).not_to be == original.updated_at
    end
  end

  describe 'aliased attributes' do
    let(:address) { Spree::Address.new(firstname: 'Ryan', lastname: 'Bigg') }

    describe '#first_name' do
      subject { address.first_name }
      it { should == 'Ryan' }
    end

    describe '#last_name' do
      subject { address.last_name }
      it { should == 'Bigg' }
    end
  end

  describe '#to_s' do
    let(:address) { stub_model(Spree::Address, full_name: 'Trung Le', address1: 'Melbourne') }
    specify { expect(address.to_s).to be == 'Trung Le: Melbourne' }
  end

  describe '#same_as?' do
    let(:country) { create(:country) }
    let(:state) { create(:state) }
    let(:address) { create(:address,
      address1:   'address1',
      address2:   'address2',
      alternative_phone: 'alternative_phone',
      city:       'city',
      country:    country,
      firstname:  'firstname',
      lastname:   'lastname',
      company:    'company',
      phone:      'phone',
      state_id:   state.id,
      state_name: state.name,
      zipcode:    'zip_code')
    }
    let(:other) { create(:address,
      address1:   'address1',
      address2:   'address2',
      alternative_phone: 'alternative_phone',
      city:       'city',
      country:    country,
      firstname:  'firstname',
      lastname:   'lastname',
      company:    'company',
      phone:      'phone',
      state_id:   state.id,
      state_name: state.name,
      zipcode:    'zip_code')
    }

    context 'other is nil' do
      specify do
        expect(address.same_as?(nil)).to be_false
        expect(address.same_as(nil)).to be_false
      end
    end

    context 'share same attributes excluding id, updated_at and created_at' do
      specify do
        expect(address.same_as?(other)).to be_true
        expect(address.same_as(other)).to be_true
      end
    end
  end

  describe '.default' do
    before do
      @default_country_id = Spree::Config[:default_country_id]
      new_country = create(:country)
      Spree::Config[:default_country_id] = new_country.id
    end

    after { Spree::Config[:default_country_id] = @default_country_id }

    it 'sets up a new record with Spree::Config[:default_country_id]' do
      expect(Spree::Address.default.country).to be == Spree::Country.find(Spree::Config[:default_country_id])
    end

    # Regression test for #1142
    it "uses the first available country if :default_country_id is set to an invalid value" do
      Spree::Config[:default_country_id] = "0"
      expect(Spree::Address.default.country).to be == Spree::Country.first
    end
  end

  describe '#full_name' do
    context 'both first and last names are present' do
      let(:address) { stub_model(Spree::Address, firstname: 'Michael', lastname: 'Jackson') }
      specify { expect(address.full_name).to be == 'Michael Jackson' }
    end

    context 'first name is blank' do
      let(:address) { stub_model(Spree::Address, firstname: nil, lastname: 'Jackson') }
      specify { expect(address.full_name).to be == 'Jackson' }
    end

    context 'last name is blank' do
      let(:address) { stub_model(Spree::Address, firstname: 'Michael', lastname: nil) }
      specify { expect(address.full_name).to be == 'Michael' }
    end

    context 'both first and last names are blank' do
      let(:address) { stub_model(Spree::Address, firstname: nil, lastname: nil) }
      specify { expect(address.full_name).to be == '' }
    end
  end

  describe '#state_text' do
    context 'state is blank' do
      let(:address) { stub_model(Spree::Address, state: nil, state_name: 'virginia') }
      specify { expect(address.state_text).to be == 'virginia' }
    end

    context 'both name and abbr is present' do
      let(:state) { stub_model(Spree::State, name: 'virginia', abbr: 'va') }
      let(:address) { stub_model(Spree::Address, state: state) }
      specify { expect(address.state_text).to be == 'va' }
    end

    context 'only name is present' do
      let(:state) { stub_model(Spree::State, name: 'virginia', abbr: nil) }
      let(:address) { stub_model(Spree::Address, state: state) }
      specify { expect(address.state_text).to be == 'virginia' }
    end
  end

  context "defines require_phone? helper method" do
    let(:address) { stub_model(Spree::Address) }
    specify { expect(address.instance_eval{ require_phone? }).to be_true }
  end
end
