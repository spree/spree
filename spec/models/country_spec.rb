require File.dirname(__FILE__) + '/../spec_helper'

describe Country do

  before(:each) do
    @country = Country.new
  end

  it "should not be valid when empty" do
    pending "Can it really be valid when empty?"
    @country.should_not be_valid
  end
  
  it "should be valid when having correct information" do
    @country.iso_name = "A Country"

    @country.should be_valid
  end


  ['iso_name'].each do |field|
    it "should require #{field}" do
      pending "Is this field mandatory?"
      @country.should_not be_valid
      @country.errors.full_messages.should include("#{field.intern.l(field).humanize} #{:error_message_blank.l}")
    end
  end
  
end
