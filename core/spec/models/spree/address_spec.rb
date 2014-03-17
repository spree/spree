require 'carmen'
require 'spec_helper'

describe Spree::Address do

  subject { Spree::Address }

  describe "clone" do
    it "creates a copy of the address with the exception of the id, updated_at and created_at attributes" do
      original = create(:address,
                         :address1 => 'address1',
                         :address2 => 'address2',
                         :alternative_phone => 'alternative_phone',
                         :city => 'city',
                         :country_code => 'US',
                         :firstname => 'firstname',
                         :lastname => 'lastname',
                         :company => 'company',
                         :phone => 'phone',
                         :region_code => 'CT',
                         :zipcode => 'zip_code')

      cloned = original.clone

      cloned.address1.should == original.address1
      cloned.address2.should == original.address2
      cloned.alternative_phone.should == original.alternative_phone
      cloned.city.should == original.city
      cloned.country_code.should == original.country_code
      cloned.firstname.should == original.firstname
      cloned.lastname.should == original.lastname
      cloned.company.should == original.company
      cloned.phone.should == original.phone
      cloned.region_code.should == original.region_code
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
    let(:address) { build(:address, :country_code => 'US') }

    it "errors when region_text is nil" do
      address.region_text = nil
      address.should_not be_valid
    end

    it "full state name is in region_text and country does contain that state" do
      address.region_text = 'alabama'
      # called by state_validate to set up state_id.
      # Perhaps this should be a before_validation instead?
      address.should be_valid
      address.region.should_not be_nil
    end

    it "region abbr is in region_text and country does contain that region" do
      address.country_code = 'US'
      address.region_text = 'AL'
      address.should be_valid
      address.region_code.should_not be_nil
      address.region.should_not be_nil
    end

    it "region is entered but country does not contain that region" do
      address.region_code = 'NSW'
      address.country_code = 'US'
      address.valid?
      address.errors["region_code"].should == ['is invalid']
    end

    it "requires phone" do
      address.phone = ""
      address.valid?
      address.errors["phone"].should == ["can't be blank"]
    end

    it "requires zipcode" do
      address.zipcode = ""
      address.valid?
      address.should have(1).error_on(:zipcode)
    end

    context "phone not required" do
      before { address.instance_eval{ self.stub :require_phone? => false } }

      it "shows no errors when phone is blank" do
        address.phone = ""
        address.valid?
        address.should have(:no).errors_on(:phone)
      end
    end

    context "zipcode not required" do
      before { address.instance_eval{ self.stub :require_zipcode? => false } }

      it "shows no errors when phone is blank" do
        address.zipcode = ""
        address.valid?
        address.should have(:no).errors_on(:zipcode)
      end
    end
  end

  context ".default" do
    context "no user given" do
      before do
        @default_country_code = Spree::Config[:default_country_code]
        new_country_code = (Carmen::Country.all.map { |c| c.code } - [@default_country_code]).sample
        Spree::Config[:default_country_code] = new_country_code
      end

      after do
        Spree::Config[:default_country_code] = @default_country_code
      end

      it "sets up a new record with Spree::Config[:default_country_code]" do
        Spree::Address.default.country_code.should == Spree::Config[:default_country_code]
      end

      # Regression test for #1142
      it "uses 'US' if :default_country_code is set to an invalid value" do
        Spree::Config[:default_country_code] = "0"
        Spree::Address.default.country_code.should == 'US'
      end
    end

    context "user given" do
      let(:bill_address) { double("BillAddress") }
      let(:ship_address) { double("ShipAddress") }
      let(:user) { double("User", bill_address: bill_address, ship_address: ship_address) }

      it "returns that user bill address" do
        expect(subject.default(user)).to eq bill_address
      end

      it "falls back to build default when user has no address" do
        user.stub(bill_address: nil)
        expect(subject.default(user)).to eq subject.build_default
      end
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

  context '#region_text' do
    context 'region name' do
      let(:address) { stub_model(Spree::Address, country_code: 'US', :region_text => 'virginia') }
      specify { address.region_text.should == 'VA' }
    end

    context 'region code in text' do
      let(:address) { stub_model(Spree::Address, country_code: 'US', :region_text => 'va') }
      specify { address.region_text.should == 'VA' }
    end

    context 'only code' do
      let(:address) { stub_model(Spree::Address, country_code: 'US', :region_code => 'va') }
      specify { address.region_text.should == 'VA' }
    end
  end

  context "defines require_phone? helper method" do
    let(:address) { stub_model(Spree::Address) }
    specify { address.instance_eval{ require_phone? }.should be_true}
  end
end
