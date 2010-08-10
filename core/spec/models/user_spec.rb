require 'spec_helper'

describe User do
  context "guest!" do
    let(:user) { User.guest! }
    it "should return a newly created user" do
      user.new_record?.should be_false
    end
  end
  it "with email should not be considered guest" do
    user = User.new(:email => "foo@example.com")
    user.guest?.should be_false
  end
  it "with no email should be considered guest" do
    user = User.new
    user.guest?.should be_true
  end
  it "can be created without email or passwords" do
    user = User.new
    user.valid?.should be_true
  end
end