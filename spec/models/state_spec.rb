require File.dirname(__FILE__) + '/../spec_helper'

describe State do

  before(:each) do
    @state = State.new
  end

  it "should not be valid when empty" do
    @state.should_not be_valid
  end

  ['country', 'name'].each do |field|
    it "should require #{field}" do
      @state.should_not be_valid
      @state.errors.full_messages.should include("#{field.intern.l(field).humanize} #{:error_message_blank.l}")
    end
  end
  
  it "should be valid when having correct information" do
    @state.name = "A State"
    @state.abbr = "ST"
    @state.country = Country.new

    @state.should be_valid
  end

end
