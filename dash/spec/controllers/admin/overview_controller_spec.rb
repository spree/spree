require 'spec_helper'

describe Spree::Admin::OverviewController do
  context '#get_report_data' do
    it 'should not allow JSON request without a valid token' do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(true)
      expect {
        get :get_report_data, { :report => 'orders_totals', :name => '7_days', :format => :js }
      }.to raise_error ActionController::InvalidAuthenticityToken
    end

    it 'should allow JSON request with missing token if forgery protection is disabled' do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(false)
      get :get_report_data, { :report => 'orders_totals', :name => '7_days', :format => :js }
      response.should be_success
    end

    it 'should allow JSON request with invalid token if forgery protection is disabled' do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(false)
      get :get_report_data, { :report => 'orders_totals', :name => '7_days', :format => :js }
      response.should be_success
    end

    it 'should allow JSON request with a valid token' do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(true)
      controller.stub :form_authenticity_token => '123456'
      get :get_report_data, { :report => 'orders_totals', :name => '7_days', :authenticity_token => '123456', :format => :js }
      response.should be_success
    end
  end
end
