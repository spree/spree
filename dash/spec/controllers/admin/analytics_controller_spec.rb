# Also see spec/requests/admin/analytics_spec.rb
require 'spec_helper'

describe Spree::Admin::AnalyticsController do
  before :each do
    @user = Factory(:admin_user)
    controller.stub :current_user => @user
  end

  it "redirects if previously registered" do
    Spree::Dash::Config.should_receive(:configured?).and_return(true)
    get :sign_up
    response.should redirect_to(spree.admin_path)
  end

  describe 'Allows sign up if not registered' do
    before :each do
      Spree::Dash::Config.app_id = nil
      Spree::Dash::Config.app_token = nil
      Spree::Dash::Config.site_id = nil
      Spree::Dash::Config.token = nil
    end

    it "sets the defaults to preferences" do
      Spree::Config.site_name = "test_site"
      Spree::Config.site_url = "http://test_site.com"
      get :sign_up
      response.should render_template("sign_up")
      assigns(:store)[:url].should eq 'http://test_site.com'
      assigns(:store)[:email].should eq @user.email
    end

    it "must agree to terms of service" do
      params = { :store => {:url => 'http://test.com' } }
      post :register, params
      flash[:error].should match /Terms of Service/
    end

    it "must agree to privacy policy" do
      params = { :store => {:terms_of_service => 'on', :url => 'http://test.com' } }
      post :register, params
      flash[:error].should match /Privacy Policy/
    end

  end
end
