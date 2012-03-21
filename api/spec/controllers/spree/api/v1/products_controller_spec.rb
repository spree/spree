require 'spec_helper'

describe Spree::Api::V1::ProductsController do
  let!(:product) { Factory(:product) }
  let(:attributes) { [:id, :name, :description, :price, :available_on, :permalink] }

  it "retrieves a list of products" do
    api_get :index
    json_response.first.should have_attributes(attributes)
  end

  it "gets a single product" do
    api_get :show, :id => product.to_param
    json_response.should have_attributes(attributes)
  end
end
