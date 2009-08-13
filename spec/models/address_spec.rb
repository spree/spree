require File.dirname(__FILE__) + '/../spec_helper'

module AddressSpecHelper
  def valid_address_attributes
    {
      :firstname => "First",
      :lastname => "Last",
      :address1 => "Address1",
      :city => "City",
      :state_name => "A State",
      :zipcode => "00000",
      :country => Country.new,
      :phone => "00000000"
    }
  end
end


describe Address do
  include AddressSpecHelper

  before(:each) do
    @address = Address.new
  end

  it "should not be valid when empty" do
    @address.should_not be_valid
  end

  ['firstname', 'lastname', 'address1', 'city', 'country', 'zipcode', 'phone'].each do |field|
    it "should require #{field}" do
      @address.should_not be_valid                    
      @address.errors.full_messages.should include("#{Address.human_attribute_name(field)} #{I18n.translate("activerecord.errors.messages.blank")}")
    end
  end

  it "should require a state name when the associated country don't have states" do
    @address.attributes = valid_address_attributes.with(:state_name => "")

    @address.should_not be_valid
    @address.errors.full_messages.should include("#{'state_name'.humanize} #{I18n.translate("activerecord.errors.messages.blank")}")
  end

  it "should require a state when the associated country have states" do
    @address.attributes = valid_address_attributes.with(
      :country => Country.new(:states => [State.new(:name => "A State", :abbr => "ST")]),
      :state_name => ""
    )

    @address.should_not be_valid
    @address.errors.full_messages.should include("#{'state'.humanize} #{I18n.translate("activerecord.errors.messages.blank")}")
  end
  
  it "should be valid when having correct information" do
    @address.attributes = valid_address_attributes
    @address.should be_valid
  end

  it "should return full name when requested" do
    @address.attributes = valid_address_attributes
    @address.full_name.should == @address.firstname + " " + @address.lastname
  end
  
  it "should return state text as state_name attribute when the associated state is nil" do
    @address.attributes = valid_address_attributes.except(:state)
    @address.state_text.should == @address.state_name
  end
    
  it "should return state text as state.name attribute when the associated state is not nil but the abbreviation is empty" do
    @address.attributes = valid_address_attributes.with(:state => State.new(:name => "A State", :abbr => ""))
    @address.state_text.should == @address.state.name
  end
    
  it "should return state text as state.abbr attribute when the associated state is not nil and the abbreviation is not empty" do
    @address.attributes = valid_address_attributes.with(:state => State.new(:name => "A State", :abbr => "ST"))
    @address.state_text.should == @address.state.abbr
  end

end
