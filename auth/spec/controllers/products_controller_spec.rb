require 'spec_helper'

describe Spree::ProductsController do
  let!(:product) { Factory(:product, :available_on => 1.year.from_now) }

  it "allows admins to view non-active products" do
    controller.should_receive(:authorize!).with(:show, Spree::Product)
    get :show, :id => product.to_param
    response.status.should == 200
  end

  it "cannot view non-active products" do
    get :show, :id => product.to_param
    response.status.should == 404
  end
end
