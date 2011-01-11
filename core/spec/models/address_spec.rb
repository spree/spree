require File.dirname(__FILE__) + '/../spec_helper'

describe Address do
  context "shoulda validations" do
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

  context "factory_girl" do
    specify { Factory(:address).new_record?.should be_false }
  end

  context "validation" do
    context "state_name is entered but country does not have any states" do
      let(:address) { Factory(:address, :state => nil, :state_name => 'alabama')}
      specify { address.new_record?.should be_false }
    end

    context "state_name is entered but country does not have that state" do
      let(:state) { Factory(:state, :name => 'virginia') }
      let(:address) { Factory.build(:address, :state => nil, :state_name => 'alabama', :country => state.country)}
      before do
        address.save
      end
      specify { address.errors.full_messages.first.should == 'State is invalid' }
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
