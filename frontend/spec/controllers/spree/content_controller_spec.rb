require 'spec_helper'
describe Spree::ContentController, :type => :controller do
  it "should not display a local file" do
    spree_get :show, :path => "../../Gemfile"
    expect(response.response_code).to eq(404)
  end

  it "should display CVV page" do
    spree_get :cvv
    expect(response.response_code).to eq(200)
  end
end
