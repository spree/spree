require 'spec_helper'

describe Spree::Admin::UsersController do
  stub_authorization!

  context "#index" do
    it "should not allow JSON request without a valid token" do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(true)
      expect {
        get :index, {:format => :json}
      }.to raise_error ActionController::InvalidAuthenticityToken
    end

    it "should allow JSON request with missing token if forgery protection is disabled" do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(false)
      get :index, {:format => :json}
      response.should be_success
    end

    it "should allow JSON request with invalid token if forgery protection is disabled" do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(false)
      get :index, {:authenticity_token => "XYZZY", :format => :json}
      response.should be_success
    end

    it "should allow JSON request with a valid token" do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(true)
      controller.stub :form_authenticity_token => "123456"
      get :index, {:authenticity_token => "123456", :format => :json}
      response.should be_success
    end

    it "should allow JSON request when token has URL(+,&,=) characters" do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(true)
      controller.stub :form_authenticity_token => "1+2=3&4'5/6?"
      get :index, {:authenticity_token => "1+2%3D3%264%275/6%3F", :format => :json}
      response.should be_success
    end

  end
end
