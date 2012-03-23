require 'spec_helper'

module Spree
  describe User do
    let(:user) { User.new }

    it "can generate an API key" do
      user.should_receive(:save!)
      user.generate_api_key!
      user.api_key.should_not be_blank
    end

    it "can clear an API key" do
      user.should_receive(:save!)
      user.clear_api_key!
      user.api_key.should be_blank
    end

    it "authenticates if a user exists with a key" do
      User.stub :find_by_api_key => stub_model(User)
      User.authenticate_for_api("fake_key").should be_true
    end

    it "does not authenticate if a user does not exist with a key" do
      User.stub :find_by_api_key => nil
      User.authenticate_for_api("fake_key").should be_false
    end
  end
end
