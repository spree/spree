require 'spec_helper'

describe "Analytics Activation" do
  stub_authorization!

  before(:each) do
    @user = create(:admin_user)

    Spree::Dash::Config.app_id = nil
    Spree::Dash::Config.app_token = nil
    Spree::Dash::Config.site_id = nil
    Spree::Dash::Config.token = nil

    Spree::Dash::Jirafe.should_receive(:register).
                        and_return({ :app_id => '1', :app_token => '2', :site_id => '3', :site_token => '4' })
  end

  it "user is signed up for analytics the first time they visit the dashboard" do
      visit spree.admin_path

      Spree::Dash::Config.app_id.should eq '1'
      Spree::Dash::Config.app_token.should eq '2'
      Spree::Dash::Config.site_id.should eq '3'
      Spree::Dash::Config.token.should eq '4'
  end

  it "can edit exisiting anayltics information" do
    visit spree.admin_path

    click_link "Configuration"
    click_link "Jirafe"
    fill_in 'app_id', :with => "1"
    fill_in 'app_token', :with => "token"
    fill_in 'site_id', :with => "test.com"
    fill_in 'token', :with => "other_token"
    click_button "Update"

    page.should have_content("Jirafe Settings have been updated.")

    Spree::Dash::Config.app_id.should eq '1'
    Spree::Dash::Config.app_token.should eq 'token'
    Spree::Dash::Config.site_id.should eq 'test.com'
    Spree::Dash::Config.token.should eq 'other_token'
  end
end
