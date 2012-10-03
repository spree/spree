require 'spec_helper'

describe Spree::Preference do

  it "should require a key" do
    @preference = Spree::Preference.new
    @preference.key = :test
    @preference.value_type = :boolean
    @preference.value = true
    @preference.should be_valid
  end

  describe "type coversion for values" do
    def round_trip_preference(key, value, value_type)
      p = Spree::Preference.new
      p.value = value
      p.value_type = value_type
      p.key = key
      p.save

      Spree::Preference.find_by_key(key)
    end

    it ":boolean" do
      value_type = :boolean
      value = true
      key = "boolean_key"
      pref = round_trip_preference(key, value, value_type)
      pref.value.should eq value
      pref.value_type.should == value_type.to_s
    end

    it "false :boolean" do
      value_type = :boolean
      value = false
      key = "boolean_key"
      pref = round_trip_preference(key, value, value_type)
      pref.value.should eq value
      pref.value_type.should == value_type.to_s
    end

    it ":integer" do
      value_type = :integer
      value = 10
      key = "integer_key"
      pref = round_trip_preference(key, value, value_type)
      pref.value.should eq value
      pref.value_type.should == value_type.to_s
    end

    it ":decimal" do
      value_type = :decimal
      value = 1.5
      key = "decimal_key"
      pref = round_trip_preference(key, value, value_type)
      pref.value.should eq value
      pref.value_type.should == value_type.to_s
    end

    it ":string" do
      value_type = :string
      value = "This is a string"
      key = "string_key"
      pref = round_trip_preference(key, value, value_type)
      pref.value.should eq value
      pref.value_type.should == value_type.to_s
    end
    
    it ":text" do
      value_type = :text
      value = "This is a string stored as text"
      key = "text_key"
      pref = round_trip_preference(key, value, value_type)
      pref.value.should eq value
      pref.value_type.should == value_type.to_s
    end

    it ":password" do
      value_type = :password
      value = "This is a password"
      key = "password_key"
      pref = round_trip_preference(key, value, value_type)
      pref.value.should eq value
      pref.value_type.should == value_type.to_s
    end

  end

  describe "converting old values" do

    it "converts true" do
      p = Spree::Preference.new
      p.value = 't'
      p.value_type = TrueClass.to_s
      Spree::Preference.convert_old_value_types(p)
      p.value_type.should == 'boolean'
      p.value.should == true
    end

    it "converts false" do
      p = Spree::Preference.new
      p.value = 'f'
      p.value_type = FalseClass.to_s
      Spree::Preference.convert_old_value_types(p)
      p.value_type.should == 'boolean'
      p.value.should == false
    end

  end

end




