require File.dirname(__FILE__) + '/../spec_helper'

module PropertySpecHelper
  def valid_property_attributes
    {
      :name => "a_property",
      :presentation => "A Property"
    }
  end
end


describe Property do
  include PropertySpecHelper

  before(:each) do
    @property = Property.new
  end

  it "should not be valid when empty" do
    @property.should_not be_valid
  end

  ['name', 'presentation'].each do |field|
    it "should require #{field}" do
      @property.should_not be_valid
      @property.errors.full_messages.should include("#{field.humanize} #{I18n.translate("activerecord.errors.messages.blank")}")
    end
  end

  it "should be valid when having correct information" do
    @property.attributes = valid_property_attributes
    @property.should be_valid
  end

  it "should find all by prototype"
  
end
