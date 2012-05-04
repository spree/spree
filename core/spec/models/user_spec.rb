require 'spec_helper'

describe Spree::User do

  context "validation" do
    it { should have_valid_factory(:user) }
  end

  context "Core::UserBanners" do
    it "save dismissed banners" do
      user = create(:user)
      user.dismiss_banner(:test_banner)
      user.dismissed_banner?(:test_banner).should be_true
    end
  end

end
