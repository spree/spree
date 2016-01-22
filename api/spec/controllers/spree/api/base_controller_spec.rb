require 'spec_helper'

class FakesController < Spree::Api::BaseController
end

describe Spree::Api::BaseController, :type => :controller do
  render_views
  controller(Spree::Api::BaseController) do
    def index
      render :text => { "products" => [] }.to_json
    end
  end

  before do
    @routes = ActionDispatch::Routing::RouteSet.new.tap do |r|
      r.draw { get 'index', to: 'spree/api/base#index' }
    end
  end

  context "when validating based on an order token" do
    let!(:order) { create :order }

    context "with a correct order token" do
      it "succeeds" do
        api_get :index, order_token: order.guest_token, order_id: order.number
        expect(response.status).to eq(200)
      end

      it "succeeds with an order_number parameter" do
        api_get :index, order_token: order.guest_token, order_number: order.number
        expect(response.status).to eq(200)
      end
    end

    context "with an incorrect order token" do
      it "returns unauthorized" do
        api_get :index, order_token: "NOT_A_TOKEN", order_id: order.number
        expect(response.status).to eq(401)
      end
    end
  end

  context "cannot make a request to the API" do
    it "without an API key" do
      api_get :index
      expect(json_response).to eq({ "error" => "You must specify an API key." })
      expect(response.status).to eq(401)
    end

    it "with an invalid API key" do
      request.headers["X-Spree-Token"] = "fake_key"
      get :index, {}
      expect(json_response).to eq({ "error" => "Invalid API key (fake_key) specified." })
      expect(response.status).to eq(401)
    end

    it "using an invalid token param" do
      get :index, :token => "fake_key"
      expect(json_response).to eq({ "error" => "Invalid API key (fake_key) specified." })
    end
  end

  it 'handles parameter missing exceptions' do
    expect(subject).to receive(:authenticate_user).and_return(true)
    expect(subject).to receive(:load_user_roles).and_return(true)
    expect(subject).to receive(:index).and_raise(ActionController::ParameterMissing.new('foo'))
    get :index, token: 'exception-message'
    expect(json_response).to eql('exception' => 'param is missing or the value is empty: foo')
  end

  it 'handles record invalid exceptions' do
    expect(subject).to receive(:authenticate_user).and_return(true)
    expect(subject).to receive(:load_user_roles).and_return(true)
    resource = Spree::Product.new
    resource.valid? # get some errors
    expect(subject).to receive(:index).and_raise(ActiveRecord::RecordInvalid.new(resource))
    get :index, token: 'exception-message'
    expect(json_response).to eql('exception' => "Validation failed: Name can't be blank, Shipping Category can't be blank, Price can't be blank")
  end

  it "maps semantic keys to nested_attributes keys" do
    klass = double(:nested_attributes_options => { :line_items => {},
                                                  :bill_address => {} })
    attributes = { 'line_items' => { :id => 1 },
                   'bill_address' => { :id => 2 },
                   'name' => 'test order' }

    mapped = subject.map_nested_attributes_keys(klass, attributes)
    expect(mapped.has_key?('line_items_attributes')).to be true
    expect(mapped.has_key?('name')).to be true
  end

  it "lets a subclass override the product associations that are eager-loaded" do
    expect(controller.respond_to?(:product_includes, true)).to be
  end
end
