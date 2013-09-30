require 'spec_helper'

describe Spree::Api::BaseController do
  render_views
  controller(Spree::Api::BaseController) do
    def index
      render :text => { "products" => [] }.to_json
    end
  end

  context "signed in as a user using an authentication extension" do
    before do
      controller.stub :try_spree_current_user => double(:email => "spree@example.com")
      Spree::Api::Config[:requires_authentication] = true
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
      request.headers["X-Spree-Token"] = "fake_key"
      get :index, {}
      json_response.should == { "error" => "Invalid API key (fake_key) specified." }
      response.status.should == 401
    end

    it "using an invalid token param" do
      get :index, :token => "fake_key"
      json_response.should == { "error" => "Invalid API key (fake_key) specified." }
    end
  end

  it 'handles exceptions' do
    subject.should_receive(:authenticate_user).and_return(true)
    subject.should_receive(:index).and_raise(Exception.new("no joy"))
    get :index, :token => "fake_key"
    json_response.should == { "exception" => "no joy" }
  end

  it "maps symantec keys to nested_attributes keys" do
    klass = double(:nested_attributes_options => { :line_items => {},
                                                  :bill_address => {} })
    attributes = { 'line_items' => { :id => 1 },
                   'bill_address' => { :id => 2 },
                   'name' => 'test order' }

    mapped = subject.map_nested_attributes_keys(klass, attributes)
    mapped.has_key?('line_items_attributes').should be_true
    mapped.has_key?('name').should be_true
  end
end
