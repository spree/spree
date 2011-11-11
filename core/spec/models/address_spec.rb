require 'spec_helper'

describe Spree::Address do
  before(:each) do
    @configuration ||= Spree::AppConfiguration.find_or_create_by_name("Default configuration")
  end

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
    it { should have_valid_factory(:address) }
  end

  context "factory" do
    let(:address) { Factory(:address) }
    specify { address.state.country.should == address.country }
  end


  context 'country usa already exists' do
    let!(:country) { Factory(:country,  :iso_name => 'UNITED STATES',
                                        :iso => 'US',
                                        :name => 'United States',
                                        :numcode => 840) }
    let(:address) { Factory(:address) }
    it 'should have country belonging to usa' do
      address.country == country
    end
  end

  context "validation" do
    let(:state) { Factory(:state, :name => 'maryland', :abbr => 'md') }
    before { Spree::Config.set :address_requires_state => true }

    context "state_name is not nil and country does not have any states" do
      let(:address) { Factory(:address, :state => nil, :state_name => 'alabama')}
      specify { address.new_record?.should be_false }
    end

    context "state_name is nil" do
      let(:address) { Factory.build(:address, :state => nil, :state_name => nil, :country => state.country)}
      before { address.save }
      specify { address.errors.full_messages.first.should == "State can't be blank" }
    end

    context "full state name is in state_name and country does contain that state" do
      let(:address) { Factory(:address, :state => nil, :state_name => 'maryland', :country => state.country)}
      before do
        Spree::State.delete_all
        Spree::Country.delete_all
        @state = Factory(:state)
        @address = Factory(:address, :state => nil, :state_name => @state.name, :country => @state.country)
      end
      specify do
        address.should be_valid
        address.state_id.should_not be_nil
        address.state_name.should be_nil
      end
    end

    context "state abbr is in state_name and country does contain that state" do
        before do
          Spree::State.delete_all
          Spree::Country.delete_all
          @state = Factory(:state)
          @address = Factory(:address, :state => nil, :state_name => @state.abbr, :country => @state.country)
        end
      specify do
        @address.should be_valid
        @address.state_id.should_not be_nil
        @address.state_name.should be_nil
      end
    end

    context "state is entered but country does not contain that state" do
      let(:address) { Factory.build(:address, :state => state, :country => Factory(:country))}
      before { address.save }

      specify { address.errors.full_messages.first.should == 'State is invalid' }
    end

    context "both state and state_name are entered but country does not contain the state" do
      let(:address) { Factory(:address, :state => state, :state_name => 'maryland', :country => Factory(:country))}
      specify do
        address.should be_valid
        address.state_id.should be_nil
      end
    end

    context "both state and state_name are entered and country does contain the state" do
      let(:address) { Factory(:address, :state => state, :state_name => 'maryland', :country => state.country)}
      specify do
        address.should be_valid
        address.state_name.should be_nil
      end
    end

    context "address_requires_state preference is false" do
      pending "need to fix config settings for specs"

      before { Spree::Config.set :address_requires_state => false }

      #let(:address) { Factory(:address, :state => nil, :state_name => nil) }
      #specify { address.should be_valid }
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
