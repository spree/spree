require 'test_helper'

class CheckoutTest < ActiveSupport::TestCase
  fixtures :gateways, :gateway_configurations

  should_belong_to :bill_address

  context Checkout do
  end
end
