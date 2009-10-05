require 'test_helper'

class NochexReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_return
    r = Nochex::Return.new('')
    assert r.success?
  end
end