require File.dirname(__FILE__) + '/../../../test_helper'

class ReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations


  def test_return
    r = Return.new('')
    assert r.success?
  end
end