require 'spec_helper'

describe Admin::OverviewController do
  context "#get_report_data" do
    it "should not allow JSON request without a valid token" do
      expect {
        get :get_report_data, {:report => 'orders_totals', :name => "7_days", :format => :js}
      }.to raise_error ActionController::InvalidAuthenticityToken
    end
    it "should allow JSON request with a valid token" do
      controller.stub :form_authenticity_token => "123456"
      get :get_report_data, {:report => 'orders_totals', :name => "7_days", :authenticity_token => "123456", :format => :js}
      response.should be_success
    end
  end
end