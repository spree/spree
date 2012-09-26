require 'spec_helper'

module Spree
  describe Payment do

    # Regression test for feature introduced in #1956
    # Previous implementation caused it to stack level too deep
    it "does not stack level too deep when asked for gateway options" do
      order = stub_model(Order, :promo_total => 1)
      payment = stub_model(Payment, :order => order)

      payment.gateway_options[:discount].should == 100
    end
  end
end
