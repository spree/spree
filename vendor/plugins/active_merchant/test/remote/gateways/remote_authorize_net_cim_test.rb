require 'test_helper'
require 'pp'

class AuthorizeNetCimTest < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = AuthorizeNetCimGateway.new(fixtures(:authorize_net))
    @amount = 100
    @credit_card = credit_card('4242424242424242')
    @payment = {
      :credit_card => @credit_card
    }
    @profile = { 
      :merchant_customer_id => 'Up to 20 chars', # Optional
      :description => 'Up to 255 Characters', # Optional
      :email => 'Up to 255 Characters', # Optional
      :payment_profiles => { # Optional
        :customer_type => 'individual', # Optional
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

  def teardown
    if @customer_profile_id
      assert response = @gateway.delete_customer_profile(:customer_profile_id => @customer_profile_id)
      assert_success response
      @customer_profile_id = nil
    end
  end

  def test_successful_profile_create_get_update_and_delete
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert_success response
    assert response.test?

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert response.test?
    assert_success response
    assert_equal @customer_profile_id, response.authorization
    assert_equal 'Successful.', response.message
    assert response.params['profile']['payment_profiles']['customer_payment_profile_id'] =~ /\d+/, 'The customer_payment_profile_id should be a number'
    assert_equal "XXXX#{@credit_card.last_digits}", response.params['profile']['payment_profiles']['payment']['credit_card']['card_number'], "The card number should contain the last 4 digits of the card we passed in #{@credit_card.last_digits}"
    assert_equal @profile[:merchant_customer_id], response.params['profile']['merchant_customer_id']
    assert_equal @profile[:description], response.params['profile']['description']
    assert_equal @profile[:email], response.params['profile']['email']
    assert_equal @profile[:payment_profiles][:customer_type], response.params['profile']['payment_profiles']['customer_type']
    assert_equal @profile[:ship_to_list][:phone_number], response.params['profile']['ship_to_list']['phone_number']
    assert_equal @profile[:ship_to_list][:company], response.params['profile']['ship_to_list']['company']

    assert response = @gateway.update_customer_profile(:profile => {:customer_profile_id => @customer_profile_id, :email => 'new email address'})
    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_nil response.params['profile']['merchant_customer_id']
    assert_nil response.params['profile']['description']
    assert_equal 'new email address', response.params['profile']['email']
  end

  def test_successful_create_customer_profile_transaction_auth_only_and_then_capture_only_requests
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    @customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :type => :auth_only,
        :amount => @amount
      }
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert_equal "This transaction has been approved.", response.params['direct_response']['message']
    assert response.params['direct_response']['approval_code'] =~ /\w{6}/
    assert_equal "auth_only", response.params['direct_response']['transaction_type']
    assert_equal "100.00", response.params['direct_response']['amount']

    approval_code = response.params['direct_response']['approval_code']

    # Capture the previously authorized funds

    assert response = @gateway.create_customer_profile_transaction(
      :transaction => {
        :customer_profile_id => @customer_profile_id,
        :customer_payment_profile_id => @customer_payment_profile_id,
        :type => :capture_only,
        :amount => @amount,
        :approval_code => approval_code
      }
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert_equal "This transaction has been approved.", response.params['direct_response']['message']
    assert_equal approval_code, response.params['direct_response']['approval_code']
    assert_equal "capture_only", response.params['direct_response']['transaction_type']
    assert_equal "100.00", response.params['direct_response']['amount']
  end

  def test_successful_create_customer_profile_transaction_auth_capture_request
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    @customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']

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

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert_equal "This transaction has been approved.", response.params['direct_response']['message']
    assert response.params['direct_response']['approval_code'] =~ /\w{6}/
    assert_equal "auth_capture", response.params['direct_response']['transaction_type']
    assert_equal "100.00", response.params['direct_response']['amount']
    assert_equal response.params['direct_response']['invoice_number'], '1234'
    assert_equal response.params['direct_response']['order_description'], 'Test Order Description'
    assert_equal response.params['direct_response']['purchase_order_number'], '4321'
  end
  
  def test_successful_create_customer_payment_profile_request
    payment_profile = @options[:profile].delete(:payment_profiles)
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_nil response.params['profile']['payment_profiles']

    assert response = @gateway.create_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :payment_profile => payment_profile
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert customer_payment_profile_id = response.params['customer_payment_profile_id']
    assert customer_payment_profile_id =~ /\d+/, "The customerPaymentProfileId should be numeric. It was #{customer_payment_profile_id}"
  end

  def test_successful_create_customer_payment_profile_request_with_bank_account
    payment_profile = @options[:profile].delete(:payment_profiles)
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_nil response.params['profile']['payment_profiles']

    assert response = @gateway.create_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :payment_profile => {
        :customer_type => 'individual', # Optional
        :bill_to => @address,
        :payment => {
          :bank_account => {
            :account_type => :checking,
            :name_on_account => 'John Doe',
            :echeck_type => :ccd,
            :bank_name => 'Bank of America',
            :routing_number => '123456789',
            :account_number => '12345'
          }
        },
        :drivers_license => {
          :state => 'MD',
          :number => '12345',
          :date_of_birth => '1981-3-31'
        },
        :tax_id => '123456789'
      }
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert customer_payment_profile_id = response.params['customer_payment_profile_id']
    assert customer_payment_profile_id =~ /\d+/, "The customerPaymentProfileId should be numeric. It was #{customer_payment_profile_id}"
  end

  def test_successful_create_customer_shipping_address_request
    shipping_address = @options[:profile].delete(:ship_to_list)
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_nil response.params['profile']['ship_to_list']

    assert response = @gateway.create_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :address => shipping_address
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert customer_address_id = response.params['customer_address_id']
    assert customer_address_id =~ /\d+/, "The customerAddressId should be numeric. It was #{customer_address_id}"
  end

  def test_successful_get_customer_profile_with_multiple_payment_profiles
    second_payment_profile = {
      :customer_type => 'individual',
      :bill_to => @address,
      :payment => {
        :credit_card => credit_card('1234123412341234')
      }
    }
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)

    assert response = @gateway.create_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :payment_profile => second_payment_profile
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert customer_payment_profile_id = response.params['customer_payment_profile_id']
    assert customer_payment_profile_id =~ /\d+/, "The customerPaymentProfileId should be numeric. It was #{customer_payment_profile_id}"
    
    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_equal 2, response.params['profile']['payment_profiles'].size
    assert_equal 'XXXX4242', response.params['profile']['payment_profiles'][0]['payment']['credit_card']['card_number']
    assert_equal 'XXXX1234', response.params['profile']['payment_profiles'][1]['payment']['credit_card']['card_number']
  end

  def test_successful_delete_customer_payment_profile_request
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']

    assert response = @gateway.delete_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => customer_payment_profile_id
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_nil response.params['profile']['payment_profiles']
  end

  def test_successful_delete_customer_shipping_address_request
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert customer_address_id = response.params['profile']['ship_to_list']['customer_address_id']

    assert response = @gateway.delete_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :customer_address_id => customer_address_id
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert_nil response.params['profile']['ship_to_list']
  end

  def test_successful_get_customer_payment_profile_request
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']

    assert response = @gateway.get_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => customer_payment_profile_id
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert response.params['payment_profile']['customer_payment_profile_id'] =~ /\d+/, 'The customer_payment_profile_id should be a number'
    assert_equal "XXXX#{@credit_card.last_digits}", response.params['payment_profile']['payment']['credit_card']['card_number'], "The card number should contain the last 4 digits of the card we passed in #{@credit_card.last_digits}"
    assert_equal @profile[:payment_profiles][:customer_type], response.params['payment_profile']['customer_type']
  end

  def test_successful_get_customer_shipping_address_request
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert customer_address_id = response.params['profile']['ship_to_list']['customer_address_id']

    assert response = @gateway.get_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :customer_address_id => customer_address_id
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert response.params['address']['customer_address_id'] =~ /\d+/, 'The customer_address_id should be a number'
    assert_equal @profile[:ship_to_list][:city], response.params['address']['city']
  end

  def test_successful_update_customer_payment_profile_request
    # Create a new Customer Profile with Payment Profile
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    # Get the customerPaymentProfileId
    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']

    # Get the customerPaymentProfile
    assert response = @gateway.get_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => customer_payment_profile_id
    )

    # The value before updating
    assert_equal "XXXX4242", response.params['payment_profile']['payment']['credit_card']['card_number'], "The card number should contain the last 4 digits of the card we passed in 4242"

    #Update the payment profile
    assert response = @gateway.update_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :payment_profile => {
        :customer_payment_profile_id => customer_payment_profile_id,
        :payment => {
          :credit_card => credit_card('1234123412341234')
        }
      }
    )
    assert response.test?
    assert_success response
    assert_nil response.authorization

    # Get the updated payment profile
    assert response = @gateway.get_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => customer_payment_profile_id
    )

    # Show that the payment profile was updated
    assert_equal "XXXX1234", response.params['payment_profile']['payment']['credit_card']['card_number'], "The card number should contain the last 4 digits of the card we passed in: 1234"
    # Show that fields that were left out of the update were cleared
    assert_nil response.params['payment_profile']['customer_type']
  end
  
  def test_successful_update_customer_shipping_address_request
    # Create a new Customer Profile with Shipping Address
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    # Get the customerAddressId
    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert customer_address_id = response.params['profile']['ship_to_list']['customer_address_id']

    # Get the customerShippingAddress
    assert response = @gateway.get_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :customer_address_id => customer_address_id
    )

    assert address = response.params['address']
    # The value before updating
    assert_equal "1234 Fake Street", address['address']

    # Update the address and remove the phone_number
    new_address = address.symbolize_keys.merge!(
      :address => '5678 Fake Street'
    )
    new_address.delete(:phone_number)

    #Update the shipping address
    assert response = @gateway.update_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :address => new_address
    )
    assert response.test?
    assert_success response
    assert_nil response.authorization

    # Get the updated shipping address
    assert response = @gateway.get_customer_shipping_address(
      :customer_profile_id => @customer_profile_id,
      :customer_address_id => customer_address_id
    )

    # Show that the shipping address was updated
    assert_equal "5678 Fake Street", response.params['address']['address']
    # Show that fields that were left out of the update were cleared
    assert_nil response.params['address']['phone_number']
  end

  def test_successful_validate_customer_payment_profile_request
    assert response = @gateway.create_customer_profile(@options)
    @customer_profile_id = response.authorization

    assert response = @gateway.get_customer_profile(:customer_profile_id => @customer_profile_id)
    assert @customer_payment_profile_id = response.params['profile']['payment_profiles']['customer_payment_profile_id']
    assert @customer_address_id = response.params['profile']['ship_to_list']['customer_address_id']

    assert response = @gateway.validate_customer_payment_profile(
      :customer_profile_id => @customer_profile_id,
      :customer_payment_profile_id => @customer_payment_profile_id,
      :customer_address_id => @customer_address_id,
      :validation_mode => :live
    )

    assert response.test?
    assert_success response
    assert_nil response.authorization
    assert_equal "This transaction has been approved.", response.params['direct_response']['message']
  end
end