require File.dirname(__FILE__) + '/../spec_helper'

module PrototypeSpecHelper
  def valid_prototype_attributes
    {
      :name => "A Prototype"
    }
  end
end


describe Prototype do
  include PrototypeSpecHelper

  before(:each) do
    @prototype = Prototype.new
  end

  it "should not be valid when empty" do
    @prototype.should_not be_valid
  end

  ['name'].each do |field|
    it "should require #{field}" do
      @prototype.should_not be_valid
      @prototype.errors.full_messages.should include("#{field.humanize} #{I18n.translate("activerecord.errors.messages.blank")}")
    end
  end

  it "should be valid when having correct information" do
    @prototype.attributes = valid_prototype_attributes
    @prototype.should be_valid
  end

end
