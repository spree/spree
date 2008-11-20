require File.dirname(__FILE__) + '/../spec_helper'

module OptionTypeSpecHelper
  def valid_option_type_attributes
    {
      :name => "an_option_type",
      :presentation => "An Option Type"
    }
  end
end


describe OptionType do
  include OptionTypeSpecHelper

  before(:each) do
    @option_type = OptionType.new
  end

  it "should not be valid when empty" do
    @option_type.should_not be_valid
  end

  ['name', 'presentation'].each do |field|
    it "should require #{field}" do
      @option_type.should_not be_valid
      @option_type.errors.full_messages.should include("#{field.intern.l(field).humanize} #{:error_message_blank.l}")
    end
  end

  it "should be valid when having correct information" do
    @option_type.attributes = valid_option_type_attributes
    @option_type.should be_valid
  end
  
end
