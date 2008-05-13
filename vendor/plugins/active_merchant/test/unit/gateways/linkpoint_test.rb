require File.dirname(__FILE__) + '/../../test_helper'

class LinkpointTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    
    @gateway = LinkpointGateway.new(
      :login => 123123,
      :pem => 'PEM'
    )

    @credit_card = credit_card('4111111111111111')
    @options = { :order_id => 1000, :billing_address => address }
  end
  
  def test_credit_card_formatting
    assert_equal '04', @gateway.send(:format_creditcard_expiry_year, 2004)
    assert_equal '04', @gateway.send(:format_creditcard_expiry_year, '2004')
    assert_equal '04', @gateway.send(:format_creditcard_expiry_year, 4)
    assert_equal '04', @gateway.send(:format_creditcard_expiry_year, '04')
  end
  
  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1000', response.authorization
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1000', response.authorization
  end
  
  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
  
  def test_recurring
    @gateway.expects(:ssl_post).returns(successful_recurring_response)
    
    assert response = @gateway.recurring(2400, @credit_card, :order_id => 1003, :installments => 12, :startdate => "immediate", :periodicity => :monthly)
    assert_success response
  end
  
  def test_amount_style
   assert_equal '10.34', @gateway.send(:amount, 1034)
                                                      
   assert_raise(ArgumentError) do
     @gateway.send(:amount, '10.34')
   end
  end

  def test_purchase_is_valid_xml
    parameters = @gateway.send(:parameters, 1000, @credit_card, :ordertype => "SALE", :order_id => 1004,
      :billing_address => {
        :address1 => '1313 lucky lane',
        :city => 'Lost Angeles',
        :state => 'CA',
        :zip => '90210'
      }
    )
  
    assert data = @gateway.send(:post_data, @amount, @credit_card, @options)
    assert REXML::Document.new(data)
  end
  
  def test_recurring_is_valid_xml
    parameters = @gateway.send(:parameters, 1000, @credit_card, :ordertype => "SALE", :action => "SUBMIT", :installments => 12, :startdate => "immediate", :periodicity => "monthly", :order_id => 1006,
      :billing_address => {
        :address1 => '1313 lucky lane',
        :city => 'Lost Angeles',
        :state => 'CA',
        :zip => '90210'
      }
    )
    assert data = @gateway.send(:post_data, @amount, @credit_card, @options)
    assert REXML::Document.new(data)
  end

  def test_declined_purchase_is_valid_xml
    @gateway = LinkpointGateway.new(:login => 123123, :pem => 'PEM')
    
    parameters = @gateway.send(:parameters, 1000, @credit_card, :ordertype => "SALE", :order_id => 1005,
      :billing_address => {
        :address1 => '1313 lucky lane',
        :city => 'Lost Angeles',
        :state => 'CA',
        :zip => '90210'
      }
    )
  
    assert data = @gateway.send(:post_data, @amount, @credit_card, @options)
    assert REXML::Document.new(data)
  end
  
  def test_overriding_test_mode
    Base.gateway_mode = :production
    
    gateway = LinkpointGateway.new(
      :login => 'LOGIN',
      :pem => 'PEM',
      :test => true
    )
    
    assert gateway.test?
  end
  
  def test_using_production_mode
    Base.gateway_mode = :production
    
    gateway = LinkpointGateway.new(
      :login => 'LOGIN',
      :pem => 'PEM'
    )
    
    assert !gateway.test?
  end
  
  def test_supported_countries
    assert_equal ['US'], LinkpointGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover], LinkpointGateway.supported_cardtypes
  end
  
  def test_avs_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'N', response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end
  
  private
  def successful_authorization_response
    '<r_csp>CSI</r_csp><r_time>Sun Jan 6 21:41:31 2008</r_time><r_ref>0004486182</r_ref><r_error/><r_ordernum>1000</r_ordernum><r_message>APPROVED</r_message><r_code>1234560004486182:NNNM:100018312899:</r_code><r_tdate>1199680890</r_tdate><r_score/><r_authresponse/><r_approved>APPROVED</r_approved><r_avs>NNNM</r_avs>'
  end
  
  def successful_purchase_response
    '<r_csp>CSI</r_csp><r_time>Sun Jan 6 21:45:22 2008</r_time><r_ref>0004486195</r_ref><r_error></r_error><r_ordernum>1000</r_ordernum><r_message>APPROVED</r_message><r_code>1234560004486195:NNNM:100018312912:</r_code><r_tdate>1199681121</r_tdate><r_score></r_score><r_authresponse></r_authresponse><r_approved>APPROVED</r_approved><r_avs>NNNM</r_avs>'    
  end
  
  def failed_purchase_response
    '<r_csp></r_csp><r_time>Sun Jan 6 21:50:51 2008</r_time><r_ref></r_ref><r_error>SGS-002300: Invalid credit card type.</r_error><r_ordernum>2aec6babe076111deb2c94c21181d9fe</r_ordernum><r_message></r_message><r_code></r_code><r_tdate></r_tdate><r_score></r_score><r_authresponse></r_authresponse><r_approved>DECLINED</r_approved><r_avs></r_avs>'
  end
  
  def successful_recurring_response
    '<r_csp>CSI</r_csp><r_time>Sun Jan 6 21:49:00 2008</r_time><r_ref>0004486198</r_ref><r_error></r_error><r_ordernum>2206b7c9a31de5fb077913134011059d</r_ordernum><r_message>APPROVED</r_message><r_code>1234560004486198:NNNM:100018312915:</r_code><r_tdate>1199681339</r_tdate><r_score></r_score><r_authresponse></r_authresponse><r_approved>APPROVED</r_approved><r_avs>NNN</r_avs>'
  end
end
