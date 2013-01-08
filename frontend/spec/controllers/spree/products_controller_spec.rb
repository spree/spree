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

  it "should provide the current user to the searcher class" do
    user = stub(:last_incomplete_spree_order => nil)
    controller.stub :spree_current_user => user
    Spree::Config.searcher_class.any_instance.should_receive(:current_user=).with(user)
    spree_get :index
    response.status.should == 200
  end

  # Regression test for #2249
  it "doesn't error when given an invalid referer" do
    controller.stub :spree_current_user => stub(:has_spree_role? => true, :last_incomplete_spree_order => nil)
    request.env['HTTP_REFERER'] = "not|a$url"
    lambda { spree_get :show, :id => product.to_param }.should_not raise_error(URI::InvalidURIError)
  end
end
