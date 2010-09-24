require 'spec_helper'

describe User do

  let(:user) { User.new }

  context "#generate_api_key!" do
    it "should set api_key to a 40 char SHA" do
      user.generate_api_key!
      user.api_key.to_s.length.should == 40
    end
  end

  context "#clear_api_key!" do
    it "should remove the existing api_key" do
      user.api_key = "FOOFAH"
      user.clear_api_key!
      user.api_key.should be_blank
    end
  end
end