require 'test_helper'

class MerchantESolutionsTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    
    @gateway = MerchantESolutionsGateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
		assert_success response
    assert_equal '5547cc97dae23ea6ad1a4abd33445c91', response.authorization
    assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

	def test_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert response.success?
    assert_equal '42e52603e4c83a55890fbbcfb92b8de1', response.authorization
    assert response.test?
  end

	def test_capture
		@gateway.expects(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.capture(@amount, '42e52603e4c83a55890fbbcfb92b8de1', @options)
    assert response.success?
		assert_equal '42e52603e4c83a55890fbbcfb92b8de1', response.authorization
    assert response.test?
	end

	def test_credit
		@gateway.expects(:ssl_post).returns(successful_credit_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert response.success?
    assert_equal '0a5ca4662ac034a59595acb61e8da025', response.authorization
    assert response.test?
	end

	def test_void
		@gateway.expects(:ssl_post).returns(successful_void_response)
		assert response = @gateway.void('42e52603e4c83a55890fbbcfb92b8de1')
    assert response.success?
		assert_equal '1b08845c6dee3fa1a73fee2a009d33a7', response.authorization
    assert response.test?
	end

	def test_store
		@gateway.expects(:ssl_post).returns(successful_store_response)
		assert response = @gateway.store(@credit_card)
    assert response.success?
		assert_equal 'ae641b57b19b3bb89faab44191479872', response.authorization
    assert response.test?
	end

	def test_unstore
		@gateway.expects(:ssl_post).returns(successful_unstore_response)
		assert response = @gateway.unstore('ae641b57b19b3bb89faab44191479872')
		assert response.success?
		assert_equal 'd79410c91b4b31ba99f5a90558565df9', response.authorization
    assert response.test?
	end

	def test_successful_avs_check
		@gateway.expects(:ssl_post).returns(successful_purchase_response + '&avs_result=Y')
    assert response = @gateway.purchase(@amount, @credit_card, @options)
		assert_equal response.avs_result['code'], "Y"
		assert_equal response.avs_result['message'], "Street address and 5-digit postal code match."
		assert_equal response.avs_result['street_match'], "Y"
		assert_equal response.avs_result['postal_match'], "Y"
	end

	def test_unsuccessful_avs_check_with_bad_street_address
		@gateway.expects(:ssl_post).returns(successful_purchase_response + '&avs_result=Z')
    assert response = @gateway.purchase(@amount, @credit_card, @options)
		assert_equal response.avs_result['code'], "Z"
		assert_equal response.avs_result['message'], "Street address does not match, but 5-digit postal code matches."
		assert_equal response.avs_result['street_match'], "N"
		assert_equal response.avs_result['postal_match'], "Y"
	end

	def test_unsuccessful_avs_check_with_bad_zip
		@gateway.expects(:ssl_post).returns(successful_purchase_response + '&avs_result=A')
    assert response = @gateway.purchase(@amount, @credit_card, @options)
		assert_equal response.avs_result['code'], "A"
		assert_equal response.avs_result['message'], "Street address matches, but 5-digit and 9-digit postal code do not match."
		assert_equal response.avs_result['street_match'], "Y"
		assert_equal response.avs_result['postal_match'], "N"
	end

	def test_successful_cvv_check
		@gateway.expects(:ssl_post).returns(successful_purchase_response + '&cvv2_result=M')
    assert response = @gateway.purchase(@amount, @credit_card, @options)
		assert_equal response.cvv_result['code'], "M"
		assert_equal response.cvv_result['message'], "Match"
	end

	def test_unsuccessful_cvv_check
		@gateway.expects(:ssl_post).returns(failed_purchase_response + '&cvv2_result=N')
    assert response = @gateway.purchase(@amount, @credit_card, @options)
		assert_equal response.cvv_result['code'], "N"
		assert_equal response.cvv_result['message'], "No Match"
	end

	def test_supported_countries
    assert_equal ['US'], MerchantESolutionsGateway.supported_countries
  end

	def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover, :jcb], MerchantESolutionsGateway.supported_cardtypes
  end

  private

  def successful_purchase_response
		'transaction_id=5547cc97dae23ea6ad1a4abd33445c91&error_code=000&auth_response_text=Exact Match&auth_code=12345A'
  end

	def successful_authorization_response
		'transaction_id=42e52603e4c83a55890fbbcfb92b8de1&error_code=000&auth_response_text=Exact Match&auth_code=12345A'
	end

	def successful_credit_response
		'transaction_id=0a5ca4662ac034a59595acb61e8da025&error_code=000&auth_response_text=Credit Approved'
	end

	def successful_void_response
		'transaction_id=1b08845c6dee3fa1a73fee2a009d33a7&error_code=000&auth_response_text=Void Request Accepted'
	end

	def successful_capture_response
		'transaction_id=42e52603e4c83a55890fbbcfb92b8de1&error_code=000&auth_response_text=Settle Request Accepted'
	end

	def successful_store_response
		'transaction_id=ae641b57b19b3bb89faab44191479872&error_code=000&auth_response_text=Card Data Stored'
	end

	def successful_unstore_response
		'transaction_id=d79410c91b4b31ba99f5a90558565df9&error_code=000&auth_response_text=Stored Card Data Deleted'
	end

  def failed_purchase_response
		'transaction_id=error&error_code=101&auth_response_text=Invalid%20I%20or%20Key%20Incomplete%20Request'
  end

end
