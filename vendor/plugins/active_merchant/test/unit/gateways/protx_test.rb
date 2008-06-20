require File.dirname(__FILE__) + '/../../test_helper'

class ProtxTest < Test::Unit::TestCase
  def setup
    @gateway = ProtxGateway.new(
      :login => 'X'
    )

    @credit_card = credit_card('4242424242424242', :type => 'visa')
    @options = { 
      :billing_address => { 
        :address1 => '25 The Larches',
        :city => "Narborough",
        :state => "Leicester",
        :zip => 'LE10 2RT'
      },
      :order_id => '1',
      :description => 'Store purchase'
    }
    @amount = 100
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_equal "1;{7307C8A9-766E-4BD1-AC41-3C34BB83F7E5};5559;WIUMDJS607", response.authorization
    assert_success response
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
  end
  
  def test_purchase_url
    assert_equal 'https://ukvpstest.protx.com/vspgateway/service/vspdirect-register.vsp', @gateway.send(:url_for, :purchase)
  end
  
  def test_capture_url
    assert_equal 'https://ukvpstest.protx.com/vspgateway/service/release.vsp', @gateway.send(:url_for, :capture)
  end
  
  def test_electron_cards
    # Visa range
    assert_no_match ProtxGateway::ELECTRON, '4245180000000000'
    
    # First electron range
    assert_match ProtxGateway::ELECTRON, '4245190000000000'
                                                                
    # Second range                                              
    assert_match ProtxGateway::ELECTRON, '4249620000000000'
    assert_match ProtxGateway::ELECTRON, '4249630000000000'
                                                                
    # Third                                                     
    assert_match ProtxGateway::ELECTRON, '4508750000000000'
                                                                
    # Fourth                                                    
    assert_match ProtxGateway::ELECTRON, '4844060000000000'
    assert_match ProtxGateway::ELECTRON, '4844080000000000'
                                                                
    # Fifth                                                     
    assert_match ProtxGateway::ELECTRON, '4844110000000000'
    assert_match ProtxGateway::ELECTRON, '4844550000000000'
                                                                
    # Sixth                                                     
    assert_match ProtxGateway::ELECTRON, '4917300000000000'
    assert_match ProtxGateway::ELECTRON, '4917590000000000'
                                                                
    # Seventh                                                   
    assert_match ProtxGateway::ELECTRON, '4918800000000000'
    
    # Visa
    assert_no_match ProtxGateway::ELECTRON, '4918810000000000'
    
    # 19 PAN length
    assert_match ProtxGateway::ELECTRON, '4249620000000000000'
    
    # 20 PAN length
    assert_no_match ProtxGateway::ELECTRON, '42496200000000000'
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
VPSProtocol=2.22 
Status=OK
StatusDetail=VSP Direct transaction from VSP Simulator.
VPSTxId={7307C8A9-766E-4BD1-AC41-3C34BB83F7E5}
SecurityKey=WIUMDJS607
TxAuthNo=5559
AVSCV2=NO DATA MATCHES
AddressResult=NOTMATCHED
PostCodeResult=MATCHED
CV2Result=NOTMATCHED
    RESP
  end
  
  def unsuccessful_purchase_response
    "VPSProtocol=2.22\r\nStatus=NOTAUTHED\r\nStatusDetail=VSP Direct transaction from VSP Simulator.\r\nVPSTxId={7BBA9078-8489-48CD-BF0D-10B0E6B0EF30}\r\nSecurityKey=DKDYLDYLXV\r\nAVSCV2=ALL MATCH\r\nAddressResult=MATCHED\r\nPostCodeResult=MATCHED\r\nCV2Result=MATCHED\r\n"
  end
end
