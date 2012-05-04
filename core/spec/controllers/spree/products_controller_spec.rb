require 'spec_helper'

describe Spree::ProductsController do
  let!(:product) { create(:product, :available_on => 1.year.from_now) }

  # Regression test for #1390
  it "cannot view non-active products" do
    get :show, :id => product.to_param
    response.status.should == 404
  end
end
