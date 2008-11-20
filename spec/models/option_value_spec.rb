require File.dirname(__FILE__) + '/../spec_helper'

module OptionValueSpecHelper
  def valid_option_value_attributes
    {
      :name => "an_option_value",
      :presentation => "An Option Value",
      :position => 1
    }
  end
end


describe OptionValue do
  include OptionValueSpecHelper

  before(:each) do
    @option_value = OptionValue.new
  end

  it "should not be valid when empty" do
    pending "Shouldn't it require a name and a presentation?"
    @option_value.should_not be_valid
  end

  ['name', 'presentation'].each do |field|
    it "should require #{field}" do
      pending "Shouldn't it require a name and a presentation?"
      @option_value.should_not be_valid
      @option_value.errors.full_messages.should include("#{field.intern.l(field).humanize} #{:error_message_blank.l}")
    end
  end

  it "should be valid when having correct information" do
    @option_value.attributes = valid_option_value_attributes
    @option_value.should be_valid
  end
  
end
