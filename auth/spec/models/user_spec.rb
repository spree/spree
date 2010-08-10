require 'spec_helper'

describe User do
  context "#create" do
    let(:user) { User.new(:email => "foo@bar.com", :password => "secret", :password_confirmation => "secret") }
    it "should create a token when saving" do
      user.save!
      user.token.should_not be_nil
    end
  end
  context "with token" do
    let(:user) { User.create(:email => "foo@bar.com", :password => "secret", :password_confirmation => "secret") }
    let(:original_token) { user.token }
    pending "#regenerate_token! should change the token" do
      user.regenerate_token!
      user.token.should_not == original_token
    end
    it "#save should not change the value of the token" do
      user.save
      user.token.should == original_token
    end
  end
end