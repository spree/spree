require File.dirname(__FILE__) + '/../../../test_helper'

class ChronopayReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_return
    r = Chronopay::Return.new('')
    assert r.success?
  end  
end

