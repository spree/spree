require 'test_helper'

class SagePayTest < Test::Unit::TestCase
  def setup
    @gateway = SagePayGateway.new(
      :login => 'X'
    )

    @credit_card = credit_card('4242424242424242', :type => 'visa')
    @options = { 
      :billing_address => { 
        :name => 'Tekin Suleyman',
        :address1 => 'Flat 10 Lapwing Court',
        :address2 => 'West Didsbury',
        :city => "Manchester",
        :county => 'Greater Manchester',
        :country => 'GB',
        :zip => 'M20 2PS'
      },
      :order_id => '1',
      :description => 'Store purchase',
      :ip => '86.150.65.37',
      :email => 'tekin@tekin.co.uk',
      :phone => '0161 123 4567'
    }
    @amount = 100
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_equal "1;B8AE1CF6-9DEF-C876-1BB4-9B382E6CE520;4193753;OHMETD7DFK;purchase", response.authorization
    assert_success response
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end
  
  def test_purchase_url
    assert_equal 'https://test.sagepay.com/gateway/service/vspdirect-register.vsp', @gateway.send(:url_for, :purchase)
  end
  
  def test_capture_url
    assert_equal 'https://test.sagepay.com/gateway/service/release.vsp', @gateway.send(:url_for, :capture)
  end
  
  def test_electron_cards
    # Visa range
    assert_no_match SagePayGateway::ELECTRON, '4245180000000000'
    
    # First electron range
    assert_match SagePayGateway::ELECTRON, '4245190000000000'
                                                                
    # Second range                                              
    assert_match SagePayGateway::ELECTRON, '4249620000000000'
    assert_match SagePayGateway::ELECTRON, '4249630000000000'
                                                                
    # Third                                                     
    assert_match SagePayGateway::ELECTRON, '4508750000000000'
                                                                
    # Fourth                                                    
    assert_match SagePayGateway::ELECTRON, '4844060000000000'
    assert_match SagePayGateway::ELECTRON, '4844080000000000'
                                                                
    # Fifth                                                     
    assert_match SagePayGateway::ELECTRON, '4844110000000000'
    assert_match SagePayGateway::ELECTRON, '4844550000000000'
                                                                
    # Sixth                                                     
    assert_match SagePayGateway::ELECTRON, '4917300000000000'
    assert_match SagePayGateway::ELECTRON, '4917590000000000'
                                                                
    # Seventh                                                   
    assert_match SagePayGateway::ELECTRON, '4918800000000000'
    
    # Visa
    assert_no_match SagePayGateway::ELECTRON, '4918810000000000'
    
    # 19 PAN length
    assert_match SagePayGateway::ELECTRON, '4249620000000000000'
    
    # 20 PAN length
    assert_no_match SagePayGateway::ELECTRON, '42496200000000000'
  end
  
  def test_avs_result
     @gateway.expects(:ssl_post).returns(successful_purchase_response)

     response = @gateway.purchase(@amount, @credit_card, @options)
     assert_equal 'Y', response.avs_result['postal_match']
     assert_equal 'N', response.avs_result['street_match']
   end

   def test_cvv_result
     @gateway.expects(:ssl_post).returns(successful_purchase_response)

     response = @gateway.purchase(@amount, @credit_card, @options)
     assert_equal 'N', response.cvv_result['code']
   end

  private

  def successful_purchase_response
    <<-RESP
VPSProtocol=2.23
Status=OK
StatusDetail=0000 : The Authorisation was Successful.
VPSTxId=B8AE1CF6-9DEF-C876-1BB4-9B382E6CE520
SecurityKey=OHMETD7DFK
TxAuthNo=4193753
AVSCV2=NO DATA MATCHES
AddressResult=NOTMATCHED
PostCodeResult=MATCHED
CV2Result=NOTMATCHED
3DSecureStatus=NOTCHECKED
    RESP
  end
  
  def unsuccessful_purchase_response
    <<-RESP
VPSProtocol=2.23
Status=NOTAUTHED
StatusDetail=VSP Direct transaction from VSP Simulator.
VPSTxId=7BBA9078-8489-48CD-BF0D-10B0E6B0EF30
SecurityKey=DKDYLDYLXV
AVSCV2=ALL MATCH
AddressResult=MATCHED
PostCodeResult=MATCHED
CV2Result=MATCHED
    RESP
  end
end
