require 'spec_helper'

describe Spree::ProductsController do
  let!(:product) { create(:product, :available_on => 1.year.from_now) }

  # Regression test for #1390
  it "allows admins to view non-active products" do
    controller.stub :spree_current_user => stub(:has_spree_role? => true, :last_incomplete_spree_order => nil)
    spree_get :show, :id => product.to_param
    response.status.should == 200
  end

  it "cannot view non-active products" do
    spree_get :show, :id => product.to_param
    response.status.should == 404
  end

  it "returns product sitemap XML" do
    spree_get :sitemap, :format => :xml
    response.status.should == 200
  end
end
