require 'spec_helper'

describe Spree::ProductsController do
  let!(:product) { Factory(:product, :available_on => 1.year.from_now) }

  before do
    controller.stub :current_user => Factory(:user)
  end

  # Regression test for #1390
  it "cannot view non-active products" do
    get :show, :id => product.to_param
    response.status.should == 404
  end
end
