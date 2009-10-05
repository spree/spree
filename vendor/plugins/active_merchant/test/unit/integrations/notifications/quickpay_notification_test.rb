require 'test_helper'

class QuickpayNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @quickpay = Quickpay::Notification.new(http_raw_data, :md5secret => "mysecretmd5string")
  end

  def test_accessors
    assert @quickpay.complete?
    assert_equal "000", @quickpay.status
    assert_equal "88", @quickpay.transaction_id
    assert_equal "order-4232", @quickpay.item_id
    assert_equal "89.50", @quickpay.gross
    assert_equal "DKK", @quickpay.currency
    assert_equal Time.parse("2008-11-05 21:57:37"), @quickpay.received_at
    assert @quickpay.test?
  end

  def test_compositions
    assert_equal Money.new(8950, 'DKK'), @quickpay.amount
  end

  def test_acknowledgement    
    assert @quickpay.acknowledge
  end
  
  def test_failed_acknnowledgement
    @quickpay = Quickpay::Notification.new(http_raw_data, :md5secret => "badmd5string")
    assert !@quickpay.acknowledge
  end

  def test_acknowledgement_with_cardnumber
    @quickpay = Quickpay::Notification.new(http_raw_data_with_cardnumber, :md5secret => "mysecretmd5string")
    assert @quickpay.acknowledge
  end
  
  def test_quickpay_attributes
    assert_equal "Authorized", @quickpay.state
    assert_equal "authorize", @quickpay.msgtype
  end

  def test_generate_md5string
    assert_equal "authorizeorder-42328950DKK081105215737Authorized000Ok000OK89898989info@pinds.com88visa-dkYesmysecretmd5string", 
                 @quickpay.generate_md5string
  end

  def test_generate_md5check
    assert_equal "e70bd0e528dc335ac74d5f1c348fe2f4", @quickpay.generate_md5check
  end

  def test_respond_to_acknowledge
    assert @quickpay.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    "msgtype=authorize&ordernumber=order-4232&amount=8950&currency=DKK&time=081105215737&state=Authorized&" + 
    "chstat=000&chstatmsg=Ok&qpstat=000&qpstatmsg=OK&merchant=89898989&merchantemail=info@pinds.com&transaction=88&" + 
    "cardtype=visa-dk&testmode=Yes&md5check=e70bd0e528dc335ac74d5f1c348fe2f4"
  end  

  def http_raw_data_with_cardnumber
    "msgtype=authorize&ordernumber=order-4232&amount=8950&currency=DKK&time=081105215737&state=Authorized&" + 
    "chstat=000&chstatmsg=Ok&qpstat=000&qpstatmsg=OK&merchant=89898989&merchantemail=info@pinds.com&transaction=88&" + 
    "cardtype=visa-dk&testmode=Yes&cardnumber=XXXXXXXXXXXX4092&md5check=bded8685e10790a9351a9d51285cec9d"
  end  
end
