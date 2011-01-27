require File.dirname(__FILE__) + '/../spec_helper'

describe MailMethod do

  context 'validation' do
    it { should have_valid_factory(:mail_method) }
  end

  context "current" do
    it "should return the first active mail method corresponding to the current environment" do
      method = MailMethod.create(:environment => "test")
      MailMethod.current.should == method
    end
  end

  context "valid?" do
    it "should be false when missing an environment value" do
      method = MailMethod.new
      method.valid?.should be_false
    end
    it "should be valid if it has an environment" do
      method = MailMethod.new(:environment => "foo")
      method.valid?.should be_true
    end
  end
end
