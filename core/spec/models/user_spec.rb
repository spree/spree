require 'spec_helper'

describe Spree::User do
  context "Core::UserBanners" do
    it "save dismissed banners" do
      user = Factory(:user)
      user.dismiss_banner(:test_banner)
      user.dismissed_banner?(:test_banner).should be_true
    end
  end

end
