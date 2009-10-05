require 'test_helper'

class GestpayReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_return
    r = Gestpay::Return.new('')
    assert r.success?
  end
end
