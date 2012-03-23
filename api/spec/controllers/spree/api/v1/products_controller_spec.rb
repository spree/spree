require 'spec_helper'

describe Spree::Api::V1::ProductsController do
  let!(:product) { Factory(:product) }
  let(:attributes) { [:id, :name, :description, :price, :available_on, :permalink] }

  before do
    stub_authentication!
  end

  it "retrieves a list of products" do
    api_get :index
    json_response.first.should have_attributes(attributes)
  end

  it "gets a single product" do
    api_get :show, :id => product.to_param
    json_response.should have_attributes(attributes)
  end

  it "cannot create a new product if not an admin" do
    api_post :create, :name => "Brand new product!"
    json_response.should == { "error" => "You are not authorized to perform that action." }
  end
end
