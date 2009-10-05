require 'test_helper'

class EfsnetTest < Test::Unit::TestCase

  def setup
    @gateway = EfsnetGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )

    @credit_card = credit_card('4242424242424242')
    @amount = 100    
    @options = { :order_id => 1, :billing_address => address }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
    assert_equal '100018347764;1.00', response.authorization
    assert_equal 'Approved', response.message
    
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
    assert_equal 'Declined', response.message
  end

  def test_authorize_is_valid_xml
    params = {
      :order_id => "order1",
      :transaction_amount => "1.01",
      :account_number => "4242424242424242",
      :expiration_month => "12",
      :expiration_year => "2029",
    }
    
    assert data = @gateway.send(:post_data, :credit_card_authorize, params)
    assert REXML::Document.new(data)
  end

  def test_settle_is_valid_xml
    params = {
      :order_id => "order1",
      :transaction_amount => "1.01",
      :original_transaction_amount => "1.01",
      :original_transaction_id => "1",
    }
    
    assert data = @gateway.send(:post_data, :credit_card_settle, params)
    assert REXML::Document.new(data)
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'N', response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end
  
  private
  def successful_purchase_response
    <<-XML
<?xml version="1.0"?>
<Reply>
  <TransactionReply>
    <ResponseCode>0</ResponseCode>
    <ResultCode>00</ResultCode>
    <ResultMessage>APPROVED</ResultMessage>
    <TransactionID>100018347764</TransactionID>
    <AVSResponseCode>N</AVSResponseCode>
    <CVVResponseCode>M</CVVResponseCode>
    <ApprovalNumber>123456</ApprovalNumber>
    <AuthorizationNumber>123456</AuthorizationNumber>
    <TransactionDate>080117</TransactionDate>
    <TransactionTime>163222</TransactionTime>
    <ReferenceNumber>1</ReferenceNumber>
    <AccountNumber>XXXXXXXXXXXX2224</AccountNumber>
    <TransactionAmount>1.00</TransactionAmount>
  </TransactionReply>
</Reply>
    XML
  end
  
  def unsuccessful_purchase_response
    <<-XML
<?xml version="1.0"?>
<Reply>
  <TransactionReply>
    <ResponseCode>256</ResponseCode>
    <ResultCode>04</ResultCode>
    <ResultMessage>DECLINED</ResultMessage>
    <TransactionID>100018347784</TransactionID>
    <AVSResponseCode>N</AVSResponseCode>
    <CVVResponseCode/>
    <ApprovalNumber/>
    <AuthorizationNumber/>
    <TransactionDate>080117</TransactionDate>
    <TransactionTime>163946</TransactionTime>
    <ReferenceNumber>1</ReferenceNumber>
    <AccountNumber>XXXXXXXXXXXX2224</AccountNumber>
    <TransactionAmount>1.56</TransactionAmount>
  </TransactionReply>
</Reply>
    XML
  end
end
