require File.dirname(__FILE__) + '/../../spec_helper'

describe Admin::ProductsController do
  context "#index" do
    it "should not allow JSON request without a valid token" do
      expect {
        get :index, {:format => :json}
      }.to raise_error ActionController::InvalidAuthenticityToken
    end
    it "should allow JSON request with a valid token" do
      controller.stub :form_authenticity_token => "123456"
      get :index, {:authenticity_token => "123456", :format => :json}
      response.should be_success
    end
  end
end
