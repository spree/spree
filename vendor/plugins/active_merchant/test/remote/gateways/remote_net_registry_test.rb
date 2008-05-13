require 'test/unit'
require File.dirname(__FILE__) + '/../../test_helper'

# To run these tests, set the variables at the top of the class
# definition.
#
# Note that NetRegistry does not provide any sort of test
# server/account, so you'll probably want to refund any uncredited
# purchases through the NetRegistry console at www.netregistry.com .
# All purchases made in these tests are $1, so hopefully you won't be
# sent broke if you forget...
class NetRegistryTest < Test::Unit::TestCase

  def setup
    @gateway = NetRegistryGateway.new(fixtures(:net_registry))

    @amount = 100
    @valid_creditcard = credit_card
    @invalid_creditcard = credit_card('41111111111111111')
    @expired_creditcard = credit_card('4111111111111111', :year => '2000')
    @invalid_month_creditcard = credit_card('4111111111111111', :month => '13')
  end

  def test_successful_purchase_and_credit
    response = @gateway.purchase(@amount, @valid_creditcard)
    assert_equal 'approved', response.params['status']
    assert_success response
    assert_match(/\A\d{16}\z/, response.authorization)

    response = @gateway.credit(@amount, response.authorization)
    assert_equal 'approved', response.params['status']
    assert_success response
  end

  # #authorize and #capture haven't been tested because the author's
  # account hasn't been setup to support these methods (see the
  # documentation for the NetRegistry gateway class).  There is no
  # mention of a #void transaction in NetRegistry's documentation,
  # either.
  if ENV['TEST_AUTHORIZE_AND_CAPTURE']
    def test_successful_authorization_and_capture
      response = @gateway.authorize(@amount, @valid_creditcard)
      assert_success response
      assert_equal 'approved', response.params['status']
      assert_match(/\A\d{6}\z/, response.authorization)

      response = @gateway.capture(@amount,
                                  response.authorization,
                                  :credit_card => @valid_creditcard)
      assert_success response
      assert_equal 'approved', response.params['status']
    end
  end

  def test_purchase_with_invalid_credit_card
    response = @gateway.purchase(@amount, @invalid_creditcard)
    assert_equal 'declined', response.params['status']
    assert_equal 'INVALID CARD', response.message
    assert_failure response
  end

  def test_purchase_with_expired_credit_card
    response = @gateway.purchase(@amount, @expired_creditcard)
    assert_equal 'failed', response.params['status']
    assert_equal 'CARD EXPIRED', response.message
    assert_failure response
  end

  def test_purchase_with_invalid_month
    response = @gateway.purchase(@amount, @invalid_month_creditcard)
    assert_equal 'failed', response.params['status']
    assert_equal 'Invalid month', response.message
    assert_failure response
  end

  def test_bad_login
    gateway = NetRegistryGateway.new(
                 :login    => 'bad-login',
                 :password => 'bad-login'
               )
    response = gateway.purchase(@amount, @valid_creditcard)
    assert_equal 'failed', response.params['status']
    assert_failure response
  end
end
