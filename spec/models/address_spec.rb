require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Address do
  it "should not validate an empty instance" do
    address = Address.new
    address.valid?.should be_false
  end
end