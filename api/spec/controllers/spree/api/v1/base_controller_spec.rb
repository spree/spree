require 'spec_helper'

describe Spree::Api::V1::BaseController do
  controller(Spree::Api::V1::BaseController) do
    def index
      render :json => { "products" => [] }
    end
  end

  context "cannot make a request to the API" do
    it "without an API key" do
      api_get :index
      json_response.should == { "error" => "You must specify an API key." }
      response.status.should == 401
    end

    it "with an invalid API key" do
      request.env["X-Spree-Token"] = "fake_key"
      get :index, {}
      json_response.should == { "error" => "Invalid API key (fake_key) specified." }
      response.status.should == 401
    end
  end
end
