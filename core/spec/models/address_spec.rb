require 'spec_helper'

describe Spree::Address do
  context "validations" do
    it { should belong_to(:country) }
    it { should belong_to(:state) }
    it { should have_many(:shipments) }
    it { should validate_presence_of(:firstname) }
    it { should validate_presence_of(:lastname) }
    it { should validate_presence_of(:address1) }
    it { should validate_presence_of(:city) }
    it { should validate_presence_of(:zipcode) }
    it { should validate_presence_of(:country) }
    it { should validate_presence_of(:phone) }
  end

  context "validation" do
    before do
      Spree::Config.set :address_requires_state => true
    end

    let(:country) { mock_model(Spree::Country, :states => [state]) }
    let(:state) { stub_model(Spree::State, :name => 'maryland', :abbr => 'md') }
    let(:address) { Spree::Address.new(FactoryGirl.attributes_for(:address, :country => country)) }

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
      address.country = stub_model(Spree::Country)
      address.valid?
      address.errors["state"].should == ['is invalid']
    end

    it "both state and state_name are entered but country does not contain the state" do
      address.state = state
      address.state_name = 'maryland'
      address.country = stub_model(Spree::Country)
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

  end

  context '#full_name' do
    let(:address) { Factory(:address, :firstname => 'Michael', :lastname => 'Jackson') }
    specify { address.full_name.should == 'Michael Jackson' }
  end

  context '#state_text' do
    context 'state is blank' do
      let(:address) { Factory(:address, :state => nil, :state_name => 'virginia') }
      specify { address.state_text.should == 'virginia' }
    end

    context 'both name and abbr is present' do
      let(:state) { Factory(:state, :name => 'virginia', :abbr => 'va') }
      let(:address) { Factory(:address, :state => state) }
      specify { address.state_text.should == 'va' }
    end

    context 'only name is present' do
      let(:state) { Factory(:state, :name => 'virginia', :abbr => nil) }
      let(:address) { Factory(:address, :state => state) }
      specify { address.state_text.should == 'virginia' }
    end

  end
end
