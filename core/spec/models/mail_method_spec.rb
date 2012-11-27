require 'spec_helper'

describe Spree::MailMethod do
  context "current" do
    it "should return the first active mail method corresponding to the current environment" do
      method = Spree::MailMethod.create(:environment => "test")
      Spree::MailMethod.current.should == method
    end
  end

  context "valid?" do
    it "should be false when missing an environment value" do
      method = Spree::MailMethod.new
      method.valid?.should be_false
    end
    it "should be valid if it has an environment" do
      method = Spree::MailMethod.new(:environment => "foo")
      method.valid?.should be_true
    end
  end
end
