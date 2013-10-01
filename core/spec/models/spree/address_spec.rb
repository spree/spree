require 'spec_helper'

describe Spree::Address do
  describe "clone" do
    it "creates a copy of the address with the exception of the id, updated_at and created_at attributes" do
      state = create(:state)
      original = create(:address,
                         :address1 => 'address1',
                         :address2 => 'address2',
                         :alternative_phone => 'alternative_phone',
                         :city => 'city',
                         :country => Spree::Country.first,
                         :firstname => 'firstname',
                         :lastname => 'lastname',
                         :company => 'company',
                         :phone => 'phone',
                         :state_id => state.id,
                         :state_name => state.name,
                         :zipcode => 'zip_code')

      cloned = original.clone

      cloned.address1.should == original.address1
      cloned.address2.should == original.address2
      cloned.alternative_phone.should == original.alternative_phone
      cloned.city.should == original.city
      cloned.country_id.should == original.country_id
      cloned.firstname.should == original.firstname
      cloned.lastname.should == original.lastname
      cloned.company.should == original.company
      cloned.phone.should == original.phone
      cloned.state_id.should == original.state_id
      cloned.state_name.should == original.state_name
      cloned.zipcode.should == original.zipcode

      cloned.id.should_not == original.id
      cloned.created_at.should_not == original.created_at
      cloned.updated_at.should_not == original.updated_at
    end
  end

  context "aliased attributes" do
    let(:address) { Spree::Address.new }

    it "first_name" do
      address.firstname = "Ryan"
      address.first_name.should == "Ryan"
    end

    it "last_name" do
      address.lastname = "Bigg"
      address.last_name.should == "Bigg"
    end
  end

  context "validation" do
    before do
      configure_spree_preferences do |config|
        config.address_requires_state = true
      end
    end

    let(:country) { mock_model(Spree::Country, :states => [state], :states_required => true) }
    let(:state) { stub_model(Spree::State, :name => 'maryland', :abbr => 'md') }
    let(:address) { build(:address, :country => country) }

    before do
      country.states.stub :find_all_by_name_or_abbr => [state]
    end

    it "state_name is not nil and country does not have any states" do
      address.state = nil
      address.state_name = 'alabama'
      address.should be_valid
    end

    it "errors when state_name is nil" do
      address.state_name = nil
      address.state = nil
      address.should_not be_valid
    end

    it "full state name is in state_name and country does contain that state" do
      address.state_name = 'alabama'
      # called by state_validate to set up state_id.
      # Perhaps this should be a before_validation instead?
      address.should be_valid
      address.state.should_not be_nil
      address.state_name.should be_nil
    end

    it "state abbr is in state_name and country does contain that state" do
      address.state_name = state.abbr
      address.should be_valid
      address.state_id.should_not be_nil
      address.state_name.should be_nil
    end

    it "state is entered but country does not contain that state" do
      address.state = state
      address.country = stub_model(Spree::Country, :states_required => true)
      address.valid?
      address.errors["state"].should == ['is invalid']
    end

    it "both state and state_name are entered but country does not contain the state" do
      address.state = state
      address.state_name = 'maryland'
      address.country = stub_model(Spree::Country, :states_required => true)
      address.should be_valid
      address.state_id.should be_nil
    end

    it "both state and state_name are entered and country does contain the state" do
      address.state = state
      address.state_name = 'maryland'
      address.should be_valid
      address.state_name.should be_nil
    end

    it "address_requires_state preference is false" do
      Spree::Config.set :address_requires_state => false
      address.state = nil
      address.state_name = nil
      address.should be_valid
    end

    it "phone is set" do
      address.phone = "123"
      address.should have(:no).errors_on(:phone)
    end

    it "phone is blank" do
      address.phone = ""
      address.valid?
      address.errors["phone"].should == ["can't be blank"]
    end

    it "require_phone? returns false and phone is blank" do
      address.instance_eval{ self.stub :require_phone? => false }
      address.phone = ""
      address.should have(:no).errors_on(:phone)
    end

  end

  context ".default" do
    before do
      @default_country_id = Spree::Config[:default_country_id]
      new_country = create(:country)
      Spree::Config[:default_country_id] = new_country.id
    end

    after do
      Spree::Config[:default_country_id] = @default_country_id
    end
    it "sets up a new record with Spree::Config[:default_country_id]" do
      Spree::Address.default.country.should == Spree::Country.find(Spree::Config[:default_country_id])
    end

    # Regression test for #1142
    it "uses the first available country if :default_country_id is set to an invalid value" do
      Spree::Config[:default_country_id] = "0"
      Spree::Address.default.country.should == Spree::Country.first
    end
  end

  context '#full_name' do
    context 'both first and last names are present' do
      let(:address) { stub_model(Spree::Address, :firstname => 'Michael', :lastname => 'Jackson') }
      specify { address.full_name.should == 'Michael Jackson' }
    end

    context 'first name is blank' do
      let(:address) { stub_model(Spree::Address, :firstname => nil, :lastname => 'Jackson') }
      specify { address.full_name.should == 'Jackson' }
    end

    context 'last name is blank' do
      let(:address) { stub_model(Spree::Address, :firstname => 'Michael', :lastname => nil) }
      specify { address.full_name.should == 'Michael' }
    end

    context 'both first and last names are blank' do
      let(:address) { stub_model(Spree::Address, :firstname => nil, :lastname => nil) }
      specify { address.full_name.should == '' }
    end

  end

  context '#state_text' do
    context 'state is blank' do
      let(:address) { stub_model(Spree::Address, :state => nil, :state_name => 'virginia') }
      specify { address.state_text.should == 'virginia' }
    end

    context 'both name and abbr is present' do
      let(:state) { stub_model(Spree::State, :name => 'virginia', :abbr => 'va') }
      let(:address) { stub_model(Spree::Address, :state => state) }
      specify { address.state_text.should == 'va' }
    end

    context 'only name is present' do
      let(:state) { stub_model(Spree::State, :name => 'virginia', :abbr => nil) }
      let(:address) { stub_model(Spree::Address, :state => state) }
      specify { address.state_text.should == 'virginia' }
    end
  end

  context "defines require_phone? helper method" do
    let(:address) { stub_model(Spree::Address) }
    specify { address.instance_eval{ require_phone? }.should be_true}
  end
end
