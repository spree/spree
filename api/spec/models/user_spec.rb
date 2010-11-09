require 'spec_helper'

describe User do

  let(:user) { User.new }

  context "#generate_api_key!" do
    it "should set authentication_token to a 20 char SHA" do
      user.generate_api_key!
      user.authentication_token.to_s.length.should == 20
    end
  end

  context "#anonymous?" do
    it "should not be anonymous" do
      user.should_not be_anonymous
    end
  end

  context "#clear_api_key!" do
    it "should remove the existing api_key" do
      user.authentication_token = "FOOFAH"
      user.clear_api_key!
      user.authentication_token.should be_blank
    end
  end
end