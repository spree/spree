require 'spec_helper'

describe Spree::Admin::BaseHelper do
  include Spree::Admin::BaseHelper

  context "#datepicker_field_value" do
    it "should return nil when date is empty" do
      date = nil
      datepicker_field_value(date).should be_nil
    end

    it "should return a formatted date when date is present" do
      date = "2013-08-14".to_time
      datepicker_field_value(date).should == "2013/08/14"
    end
  end

  context "rails environments" do
    it "returns the existing environments" do
      Dir.stub(:glob).and_return ["./config/environments/development.rb", "./config/environments/production.rb","./config/environments/staging.rb", "./config/environments/test.rb"]
      expect(rails_environments).to eql ["development","production", "staging", "test"]
    end
  end

end
