require 'spec_helper'

describe Spree::Admin::ShippingMethodsController do
  stub_authorization!

  # Regression test for #1240
  it "should not hard-delete shipping methods" do
    Spree::ShippingMethod.should_receive(:find).and_return(shipping_method = stub_model(Spree::ShippingMethod))
    shipping_method.should_not_receive(:destroy)
    shipping_method.deleted_at.should be_nil
    spree_delete :destroy, :id => 1
    shipping_method.deleted_at.should_not be_nil
  end
end
