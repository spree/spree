require 'spec_helper'

describe Spree::Preference do

  it "should require a key" do
    @preference = Spree::Preference.new
    @preference.key = :test
    @preference.should be_valid
  end

  it "sets the value type with value" do
    @preference = Spree::Preference.new

    @preference.value = true
    @preference.value_type.should eq TrueClass.to_s

    @preference.value = "test"
    @preference.value_type.should eq String.to_s
  end

  describe "type coversion for values" do
    def round_trip_preference(key, value)
      p = Spree::Preference.new
      p.value = value
      p.key = key
      p.save

      Spree::Preference.find_by_key(key)
    end

    it "Symbol" do
      value = :fbi
      key = "fox/mulder"
      pref = round_trip_preference(key, value)
      pref.value.should eq value
      pref.value.class.should eq value.class
    end

    it "Fixnum" do
      value = 1234
      key = "hipster"
      pref = round_trip_preference(key, value)
      pref.value.should eq value
      pref.value.class.should eq value.class
    end

    it "Bignum" do
      value = 2342341234123409981440 #in db as "2.34234123412341e+21"
      key = "notorious/b/i/g"
      pref = round_trip_preference(key, value)
      pref.value.should eq value
      pref.value.class.should eq value.class
    end

    it "Float" do
      value = 3.14
      key = "apple/pie"
      pref = round_trip_preference(key, value)
      pref.value.should eq value
      pref.value.class.should eq value.class
    end

    it "TrueClass" do
      value = true
      key = "you/cant/handle"
      pref = round_trip_preference(key, value)
      pref.value.should eq value
      pref.value.class.should eq value.class
    end

    it "FalseClass" do
      value = false
      key = "ll/cool/j"
      pref = round_trip_preference(key, value)
      pref.value.should eq value
      pref.value.class.should eq value.class
    end

  end

end




