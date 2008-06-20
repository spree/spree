require File.dirname(__FILE__) + '/../../../test_helper'

class HiTrustReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_successful_return
    r = HiTrust::Return.new('order_id=&mscssid=&retcode=00&ordernumber=1138742&type=Auth')
    assert r.success?
    assert_equal HiTrust::Return::SUCCESS, r.params['retcode']
    assert_equal HiTrust::Return::CODES[HiTrust::Return::SUCCESS], r.message
  end
  
  def test_failed_return
    r = HiTrust::Return.new('retcode=-100')
    assert_false r.success?
    assert_equal HiTrust::Return::CODES['-100'], r.message
  end
  
  def test_unknown_return
    r = HiTrust::Return.new('retcode=unknown')
    assert_false r.success?
    assert_nil r.message
  end
end
