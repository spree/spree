require 'spec_helper'

describe Spree::Preference do
  before :each do
    @preference = Spree::Preference.new
  end

  it "should require a key" do
    @preference.key = :test
    @preference.should be_valid
  end

  it "sets the value type with value" do
    @preference.value = true
    @preference.value_type.should eq TrueClass.to_s

    @preference.value = "test"
    @preference.value_type.should eq String.to_s
  end

  it "converts the value to the value_type" do
    @preference.value = "1"
    @preference.value_type = Fixnum.to_s
    @preference.value.should be_instance_of Fixnum
  end
end




