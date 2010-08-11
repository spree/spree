require 'spec_helper'

describe User do
  context "#create" do
    let(:user) { User.new(:email => "foo@bar.com", :password => "secret", :password_confirmation => "secret") }
    it "should create a token when saving" do
      user.save!
      user.authentication_token.should_not be_nil
    end
  end
  context "guest!" do
    let(:user) { User.guest! }
    it "should return a newly created user" do
      user.new_record?.should be_false
    end
  end
end