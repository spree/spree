# Also see spec/requests/admin/analytics_spec.rb
require 'spec_helper'

describe Spree::Admin::AnalyticsController do
  before :each do
    @user = create(:admin_user)
    controller.stub :spree_current_user => @user
  end

  it "redirects if already registered" do
    Spree::Dash::Config.should_receive(:configured?).and_return(true)
    spree_get :register
    response.should redirect_to(spree.admin_path)
  end

  describe 'Allows registration if not registered' do
    before :each do
      Spree::Dash::Config.app_id = nil
      Spree::Dash::Config.app_token = nil
      Spree::Dash::Config.site_id = nil
      Spree::Dash::Config.token = nil
    end

    it "redirects after registration" do
      Spree::Config.site_name = "test_site"
      Spree::Config.site_url = "http://test_site.com"
      spree_get :register
      response.should redirect_to(spree.admin_path)
    end

    it "configures dash during registration" do
      Spree::Dash::Jirafe.should_receive(:register).
                          and_return({ :app_id => '1', :app_token => '2', :site_id => '3', :site_token => '4' })
      spree_get :register
      Spree::Dash::Config.configured?.should be_true
      response.should redirect_to(spree.admin_path)
    end
  end
end
