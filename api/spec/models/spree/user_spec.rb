require 'spec_helper'

module Spree
  describe User do
    let(:user) { User.new }

    it "can generate an API key" do
      user.should_receive(:save!)
      user.generate_spree_api_key!
      user.spree_api_key.should_not be_blank
    end

    it "can clear an API key" do
      user.should_receive(:save!)
      user.clear_spree_api_key!
      user.spree_api_key.should be_blank
    end
  end
end
