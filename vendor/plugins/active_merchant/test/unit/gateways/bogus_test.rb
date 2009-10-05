require 'test_helper'

class BogusTest < Test::Unit::TestCase
  def setup
    @gateway = BogusGateway.new(
      :login => 'bogus',
      :password => 'bogus'
    )
    
    @creditcard = credit_card('1')
    
    @response = ActiveMerchant::Billing::Response.new(true, "Transaction successful", :transid => BogusGateway::AUTHORIZATION)
  end

  def test_authorize
    @gateway.capture(1000, @creditcard)    
  end

  def test_purchase
    @gateway.purchase(1000, @creditcard)    
  end

  def test_credit
    @gateway.credit(1000, @response.params["transid"])
  end

  def test_void
    @gateway.void(@response.params["transid"])
  end
  
  def  test_store
    @gateway.store(@creditcard)
  end
  
  def test_unstore
    @gateway.unstore('1')
  end
  
  def test_supported_countries
    assert_equal ['US'], BogusGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:bogus], BogusGateway.supported_cardtypes
  end
end
