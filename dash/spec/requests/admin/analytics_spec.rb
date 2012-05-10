require 'spec_helper'

describe "Analytics Activation" do
  before(:each) do
    @user = create(:admin_user)
    Spree::Admin::AnalyticsController.any_instance.stub :spree_current_user => @user

    Spree::Dash::Config.app_id = nil
    Spree::Dash::Config.app_token = nil
    Spree::Dash::Config.site_id = nil
    Spree::Dash::Config.token = nil
  end

  it "user can activate spree_analytics" do
      Spree::Dash::Jirafe.should_receive(:register).
                          with(hash_including(:url => 'http://test.com')).
                          and_return({ :app_id => '1', :app_token => '2', :site_id => '3', :site_token => '4' })

      visit spree.admin_analytics_sign_up_path
      check 'store[terms_of_service]'
      check 'store[privacy_policy]'
      fill_in 'store[first_name]', :with => "test_first_name"
      fill_in 'store[last_name]', :with => "test_last_name"
      fill_in 'store[url]', :with => "test.com"
      select '(GMT+00:00) Casablanca', :from => 'store[time_zone]'
      click_button 'Activate'

      Spree::Dash::Config.app_id.should eq '1'
      Spree::Dash::Config.app_token.should eq '2'
      Spree::Dash::Config.site_id.should eq '3'
      Spree::Dash::Config.token.should eq '4'
  end
end
