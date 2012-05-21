require 'spec_helper'

describe Spree::ProductsController do
  let!(:product) { create(:product, :available_on => 1.year.from_now) }
  # Regression test for #1390
  it "allows admins to view non-active products" do
    controller.stub :current_user => stub(:has_role? => true)
    get :show, :id => product.to_param
    response.status.should == 200
  end

  # Regression test for #1390
  it "cannot view non-active products" do
    controller.stub :current_user => stub(:has_role? => false)
    get :show, :id => product.to_param
    response.status.should == 404
  end
end
