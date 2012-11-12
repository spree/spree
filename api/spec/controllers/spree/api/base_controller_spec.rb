require 'spec_helper'

describe Spree::Api::BaseController do
  render_views
  controller(Spree::Api::BaseController) do
    def index
      render :json => { "products" => [] }
    end
  end

  context "signed in as a user using an authentication extension" do
    before do
      controller.stub :try_spree_current_user => stub(:email => "spree@example.com")
    end

    it "can make a request" do
      api_get :index
      json_response.should == { "products" => [] }
      response.status.should == 200
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

    it "using an invalid token param" do
      get :index, :token => "fake_key"
      json_response.should == { "error" => "Invalid API key (fake_key) specified." }
    end
  end

  it "maps symantec keys to nested_attributes keys" do
    klass = stub(:nested_attributes_options => { :line_items => {},
                                                  :bill_address => {} })
    attributes = { 'line_items' => { :id => 1 },
                   'bill_address' => { :id => 2 },
                   'name' => 'test order' }

    mapped = subject.map_nested_attributes_keys(klass, attributes)
    mapped.has_key?('line_items_attributes').should be_true
    mapped.has_key?('name').should be_true
  end
end
