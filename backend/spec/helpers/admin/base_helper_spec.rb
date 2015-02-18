require 'spec_helper'

describe Spree::Admin::BaseHelper, :type => :helper do
  include Spree::Admin::BaseHelper

  context "#datepicker_field_value" do
    it "should return nil when date is empty" do
      date = nil
      expect(datepicker_field_value(date)).to be_nil
    end

    it "should return a formatted date when date is present" do
      date = "2013-08-14".to_time
      expect(datepicker_field_value(date)).to eq("2013/08/14")
    end
  end

  context "#plural_resource_name" do
    it "should return correct form of class" do
      resource_class = Spree::Product
      expect(plural_resource_name(resource_class)).to eq("Products")
    end
  end
end
