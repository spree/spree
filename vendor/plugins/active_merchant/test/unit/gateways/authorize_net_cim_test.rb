require 'test_helper'

class AuthorizeNetCimTest < Test::Unit::TestCase
  def setup
    @gateway = AuthorizeNetCimGateway.new(
      :login => 'X',
      :password => 'Y'
    )
    @amount = 100
    @credit_card = credit_card
    @address = address
    @customer_profile_id = '3187'
    @customer_payment_profile_id = '7813'
    @customer_address_id = '4321'
    @payment = {
      :credit_card => @credit_card
    }
    @profile = { 
      :merchant_customer_id => 'Up to 20 chars', # Optional
      :description => 'Up to 255 Characters', # Optional
      :email => 'Up to 255 Characters', # Optional
      :payment_profiles => { # Optional
        :customer_type => 'individual or business', # Optional
        :bill_to => @address,
        :payment => @payment
      },
      :ship_to_list => {
        :first_name => 'John', 
        :last_name => 'Doe', 
        :company => 'Widgets, Inc',
        :address1 => '1234 Fake Street',
        :city => 'Anytown',
        :state => 'MD',
        :zip => '12345',
        :country => 'USA',
        :phone_number => '(123)123-1234', # Optional - Up to 25 digits (no letters)
        :fax_number => '(123)123-1234' # Optional - Up to 25 digits (no letters)
      }
    }
    @options = {
      :ref_id => '1234', # Optional
      :profile => @profile
    }
  end
  
  def test_expdate_formatting
    assert_equal '2009-09', @gateway.send(:expdate, credit_card('4111111111111111', :month => "9", :year => "2009"))
    assert_equal '2013-11', @gateway.send(:expdate, credit_card('4111111111111111', :month => "11", :year => "2013"))
  end
  
  def test_should_create_customer_profile_request
    @gateway.expects(:ssl_post).returns(successful_create_customer_profile_response)

    assert response = @gateway.create_customer_profile(@options)
    assert_instance_of Response, response
    assert_success response
    assert_equal @customer_profile_id, response.authorization
    assert_equal "Successful.", response.message
  end

  def test_should_create_customer_payment_profile_request
    @gateway.expects(:ssl_post).returns(successful_create_customer_payment_profile_response)

    assert response = @gateway.create_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :payment_profile => {
        :customer_type => 'individual',
        :bill_to => @address,
        :payment => @payment
      },
      :validation_mode => :test
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal @customer_payment_profile_id, response.params['customer_payment_profile_id']
    assert_equal "This output is only present if the ValidationMode input parameter is passed with a value of testMode or liveMode", response.params['validation_direct_response']
  end

  def test_should_create_customer_shipping_address_request
    @gateway.expects(:ssl_post).returns(successful_create_customer_shipping_address_response)

    assert response = @gateway.create_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :address => {
        :first_name => 'John', 
        :last_name => 'Doe', 
        :company => 'Widgets, Inc',
        :address1 => '1234 Fake Street',
        :city => 'Anytown',
        :state => 'MD',
        :country => 'USA',
        :phone_number => '(123)123-1234',
        :fax_number => '(123)123-1234'
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
    assert_equal 'customerAddressId', response.params['customer_address_id']
  end

  def test_should_create_customer_profile_transaction_auth_only_and_then_capture_only_requests
    @gateway.expects(:ssl_post).returns(successful_create_customer_profile_transaction_response(:auth_only))

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :customer_profile_id => @customer_profile_id, 
        :customer_payment_profile_id => @customer_payment_profile_id, 
        :type => :auth_only, 
        :amount => @amount
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
    assert_equal 'auth_only', response.params['direct_response']['transaction_type']
    assert_equal 'Gw4NGI', approval_code = response.params['direct_response']['approval_code']

    @gateway.expects(:ssl_post).returns(successful_create_customer_profile_transaction_response(:capture_only))

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :type => :capture_only,
        :amount => @amount,
        :approval_code => approval_code
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
  end

  def test_should_create_customer_profile_transaction_auth_capture_request
    @gateway.expects(:ssl_post).returns(successful_create_customer_profile_transaction_response(:auth_capture))

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :type => :auth_capture,
        :order => {
          :invoice_number => '1234',
          :description => 'Test Order Description',
          :purchase_order_number => '4321'
        },
        :amount => @amount
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
  end

  def test_should_delete_customer_profile_request
    @gateway.expects(:ssl_post).returns(successful_delete_customer_profile_response)

    assert response = @gateway.delete_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_instance_of Response, response
    assert_success response
    assert_equal @customer_profile_id, response.authorization
  end

  def test_should_delete_customer_payment_profile_request
    @gateway.expects(:ssl_post).returns(successful_delete_customer_payment_profile_response)

    assert response = @gateway.delete_customer_payment_profile(:customer_profile_id => @customer_profile_id, :customer_payment_profile_id => @customer_payment_profile_id)
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
  end

  def test_should_delete_customer_shipping_address_request
    @gateway.expects(:ssl_post).returns(successful_delete_customer_shipping_address_response)

    assert response = @gateway.delete_customer_shipping_address(:customer_profile_id => @customer_profile_id, :customer_address_id => @customer_address_id)
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
  end

  def test_should_get_customer_profile_request
    @gateway.expects(:ssl_post).returns(successful_get_customer_profile_response)

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_instance_of Response, response
    assert_success response
    assert_equal @customer_profile_id, response.authorization
  end

  def test_should_get_customer_profile_request_with_multiple_payment_profiles
    @gateway.expects(:ssl_post).returns(successful_get_customer_profile_response_with_multiple_payment_profiles)

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_instance_of Response, response
    assert_success response

    assert_equal @customer_profile_id, response.authorization
    assert_equal 2, response.params['profile']['payment_profiles'].size
  end

  def test_should_get_customer_payment_profile_request
    @gateway.expects(:ssl_post).returns(successful_get_customer_payment_profile_response)

    assert response = @gateway.get_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => @customer_payment_profile_id
    )
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
    assert_equal @customer_payment_profile_id, response.params['profile']['payment_profiles']['customer_payment_profile_id']
  end

  def test_should_get_customer_shipping_address_request
    @gateway.expects(:ssl_post).returns(successful_get_customer_shipping_address_response)

    assert response = @gateway.get_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :customer_address_id => @customer_address_id
    )
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
  end

  def test_should_update_customer_profile_request
    @gateway.expects(:ssl_post).returns(successful_update_customer_profile_response)

    assert response = @gateway.update_customer_profile(
      :profile => {
        :customer_profile_id => @customer_profile_id,
        :email => 'new email address'
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_equal @customer_profile_id, response.authorization
  end

  def test_should_update_customer_payment_profile_request
    @gateway.expects(:ssl_post).returns(successful_update_customer_payment_profile_response)

    assert response = @gateway.update_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :payment_profile => {
        :customer_payment_profile_id => @customer_payment_profile_id,
        :customer_type => 'business'
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
  end

  def test_should_update_customer_shipping_address_request
    @gateway.expects(:ssl_post).returns(successful_update_customer_shipping_address_response)

    assert response = @gateway.update_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :address => {
        :customer_address_id => @customer_address_id,
        :city => 'New City'
      }
    )
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
  end

  def test_should_validate_customer_payment_profile_request
    @gateway.expects(:ssl_post).returns(successful_validate_customer_payment_profile_response)
  
    assert response = @gateway.validate_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => @customer_payment_profile_id,
      :customer_address_id => @customer_address_id,
      :validation_mode => :live
    )
    assert_instance_of Response, response
    assert_success response
    assert_nil response.authorization
    assert_equal 'This transaction has been approved.', response.params['direct_response']['message']
  end

  private
  
  def successful_create_customer_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <createCustomerProfileResponse 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"> 
        <refId>refid1</refId> 
        <messages> 
          <resultCode>Ok</resultCode> 
          <message> 
            <code>I00001</code> 
            <text>Successful.</text> 
          </message> 
        </messages> 
        <customerProfileId>#{@customer_profile_id}</customerProfileId> 
      </createCustomerProfileResponse>
    XML
  end

  def successful_create_customer_payment_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <createCustomerPaymentProfileResponse 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"> 
        <refId>refid1</refId> 
        <messages>
          <resultCode>Ok</resultCode> 
          <message> 
            <code>I00001</code> 
            <text>Successful.</text> 
          </message> 
        </messages> 
        <customerPaymentProfileId>#{@customer_payment_profile_id}</customerPaymentProfileId>
        <validationDirectResponse>This output is only present if the ValidationMode input parameter is passed with a value of testMode or liveMode</validationDirectResponse>
      </createCustomerPaymentProfileResponse>
    XML
  end

  def successful_create_customer_shipping_address_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <createCustomerShippingAddressResponse 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"> 
        <refId>refid1</refId> 
        <messages>
          <resultCode>Ok</resultCode> 
          <message> 
            <code>I00001</code> 
            <text>Successful.</text> 
          </message> 
        </messages> 
        <customerAddressId>customerAddressId</customerAddressId>
      </createCustomerShippingAddressResponse>
    XML
  end

  def successful_delete_customer_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <deleteCustomerProfileResponse 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"> 
        <refId>refid1</refId> 
        <messages> 
          <resultCode>Ok</resultCode> 
          <message> 
            <code>I00001</code> 
            <text>Successful.</text> 
          </message> 
        </messages> 
        <customerProfileId>#{@customer_profile_id}</customerProfileId> 
      </deleteCustomerProfileResponse>
    XML
  end

  def successful_delete_customer_payment_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <deleteCustomerPaymentProfileResponse 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"> 
        <refId>refid1</refId> 
        <messages> 
          <resultCode>Ok</resultCode> 
          <message> 
            <code>I00001</code> 
            <text>Successful.</text> 
          </message> 
        </messages> 
      </deleteCustomerPaymentProfileResponse>
    XML
  end

  def successful_delete_customer_shipping_address_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <deleteCustomerShippingAddressResponse 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"> 
        <refId>refid1</refId> 
        <messages> 
          <resultCode>Ok</resultCode> 
          <message> 
            <code>I00001</code> 
            <text>Successful.</text> 
          </message> 
        </messages> 
      </deleteCustomerShippingAddressResponse>
    XML
  end

  def successful_get_customer_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <getCustomerProfileResponse 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"> 
        <refId>refid1</refId> 
        <messages> 
          <resultCode>Ok</resultCode> 
          <message> 
            <code>I00001</code> 
            <text>Successful.</text> 
          </message> 
        </messages> 
        <customerProfileId>#{@customer_profile_id}</customerProfileId>
        <profile>
          <paymentProfiles>
            <customerPaymentProfileId>123456</customerPaymentProfileId>
            <payment>
              <creditCard>
                  <cardNumber>#{@credit_card.number}</cardNumber>
                  <expirationDate>#{@gateway.send(:expdate, @credit_card)}</expirationDate>
              </creditCard>
            </payment>
          </paymentProfiles>
        </profile>
      </getCustomerProfileResponse>
    XML
  end

  def successful_get_customer_profile_response_with_multiple_payment_profiles
    <<-XML
      <?xml version="1.0" encoding="utf-8"?>
      <getCustomerProfileResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
        <messages>
          <resultCode>Ok</resultCode>
          <message>
            <code>I00001</code>
            <text>Successful.</text>
          </message>
        </messages>
        <profile>
          <merchantCustomerId>Up to 20 chars</merchantCustomerId>
          <description>Up to 255 Characters</description>
          <email>Up to 255 Characters</email>
          <customerProfileId>#{@customer_profile_id}</customerProfileId>
          <paymentProfiles>
            <customerPaymentProfileId>1000</customerPaymentProfileId>
            <payment>
              <creditCard>
                <cardNumber>#{@credit_card.number}</cardNumber>
                <expirationDate>#{@gateway.send(:expdate, @credit_card)}</expirationDate>
              </creditCard>
            </payment>
          </paymentProfiles>
          <paymentProfiles>
            <customerType>individual</customerType>
            <customerPaymentProfileId>1001</customerPaymentProfileId>
            <payment>
              <creditCard>
                <cardNumber>XXXX1234</cardNumber>
                <expirationDate>XXXX</expirationDate>
              </creditCard>
            </payment>
          </paymentProfiles>
        </profile>
      </getCustomerProfileResponse>
    XML
  end

  def successful_get_customer_payment_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <getCustomerPaymentProfileResponse 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"> 
        <refId>refid1</refId> 
        <messages> 
          <resultCode>Ok</resultCode> 
          <message> 
            <code>I00001</code> 
            <text>Successful.</text> 
          </message> 
        </messages> 
        <profile>
          <paymentProfiles>
            <customerPaymentProfileId>#{@customer_payment_profile_id}</customerPaymentProfileId>
            <payment>
              <creditCard>
                  <cardNumber>#{@credit_card.number}</cardNumber>
                  <expirationDate>#{@gateway.send(:expdate, @credit_card)}</expirationDate>
              </creditCard>
            </payment>
          </paymentProfiles>
        </profile>
      </getCustomerPaymentProfileResponse>
    XML
  end

  def successful_get_customer_shipping_address_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <getCustomerShippingAddressResponse 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"> 
        <refId>refid1</refId> 
        <messages> 
          <resultCode>Ok</resultCode> 
          <message> 
            <code>I00001</code> 
            <text>Successful.</text> 
          </message> 
        </messages> 
        <address>
          <customerAddressId>#{@customer_address_id}</customerAddressId>
        </address>
      </getCustomerShippingAddressResponse>
    XML
  end

  def successful_update_customer_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <updateCustomerProfileResponse 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"> 
        <refId>refid1</refId> 
        <messages> 
          <resultCode>Ok</resultCode> 
          <message> 
            <code>I00001</code> 
            <text>Successful.</text> 
          </message> 
        </messages> 
        <customerProfileId>#{@customer_profile_id}</customerProfileId> 
      </updateCustomerProfileResponse>
    XML
  end

  def successful_update_customer_payment_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <updateCustomerPaymentProfileResponse 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"> 
        <refId>refid1</refId> 
        <messages> 
          <resultCode>Ok</resultCode> 
          <message> 
            <code>I00001</code> 
            <text>Successful.</text> 
          </message> 
        </messages> 
      </updateCustomerPaymentProfileResponse>
    XML
  end

  def successful_update_customer_shipping_address_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <updateCustomerShippingAddressResponse 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"> 
        <refId>refid1</refId> 
        <messages> 
          <resultCode>Ok</resultCode> 
          <message> 
            <code>I00001</code> 
            <text>Successful.</text> 
          </message> 
        </messages> 
      </updateCustomerShippingAddressResponse>
    XML
  end

  SUCCESSFUL_DIRECT_RESPONSE = {
    :auth_only => '1,1,1,This transaction has been approved.,Gw4NGI,Y,508223659,,,100.00,CC,auth_only,Up to 20 chars,,,,,,,,,,,Up to 255 Characters,,,,,,,,,,,,,,6E5334C13C78EA078173565FD67318E4,,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,',
    :capture_only => '1,1,1,This transaction has been approved.,,Y,508223660,,,100.00,CC,capture_only,Up to 20 chars,,,,,,,,,,,Up to 255 Characters,,,,,,,,,,,,,,6E5334C13C78EA078173565FD67318E4,,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,',
    :auth_capture => '1,1,1,This transaction has been approved.,d1GENk,Y,508223661,32968c18334f16525227,Store purchase,1.00,CC,auth_capture,,Longbob,Longsen,,,,,,,,,,,,,,,,,,,,,,,269862C030129C1173727CC10B1935ED,P,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,'
  }

  def successful_create_customer_profile_transaction_response(transaction_type)
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <createCustomerProfileTransactionResponse 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"> 
        <refId>refid1</refId> 
        <messages> 
          <resultCode>Ok</resultCode> 
          <message> 
            <code>I00001</code> 
            <text>Successful.</text> 
          </message> 
        </messages> 
        <directResponse>#{SUCCESSFUL_DIRECT_RESPONSE[transaction_type]}</directResponse>
      </createCustomerProfileTransactionResponse>
    XML
  end
  
  def successful_validate_customer_payment_profile_response
    <<-XML
      <?xml version="1.0" encoding="utf-8" ?> 
      <validateCustomerPaymentProfileResponse 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
        xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"> 
        <refId>refid1</refId> 
        <messages> 
          <resultCode>Ok</resultCode> 
          <message> 
            <code>I00001</code> 
            <text>Successful.</text> 
          </message> 
        </messages> 
        <directResponse>1,1,1,This transaction has been approved.,DEsVh8,Y,508276300,none,Test transaction for ValidateCustomerPaymentProfile.,0.01,CC,auth_only,Up to 20 chars,,,,,,,,,,,Up to 255 Characters,John,Doe,Widgets, Inc,1234 Fake Street,Anytown,MD,12345,USA,0.0000,0.0000,0.0000,TRUE,none,7EB3A44624C0C10FAAE47E276B48BF17,,2,,,,,,,,,,,,,,,,,,,,,,,,,,,,</directResponse>
      </validateCustomerPaymentProfileResponse>
    XML
  end
  
end
