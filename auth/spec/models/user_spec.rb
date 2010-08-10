require 'spec_helper'

describe User do
  context "#create" do
    let(:user) { User.new(:email => "foo@bar.com", :password => "secret", :password_confirmation => "secret") }
    it "should create a token when saving" do
      user.save!
      user.token.should_not be_nil
    end
  end
  context "#regenerate_token!" do
    it "should change the token"
  end
end