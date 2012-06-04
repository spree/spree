require 'spec_helper'

describe Spree::Admin::ShippingMethodsController do
  
  # Regression test for #1240
  it "should not hard-delete shipping methods" do
    Spree::ShippingMethod.should_receive(:find).and_return(shipping_method = stub_model(Spree::ShippingMethod))
    shipping_method.should_not_receive(:destroy)
    shipping_method.should_receive(:update_attribute)
    delete :destroy, :id => 1
  end
end
