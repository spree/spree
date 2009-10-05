require 'test_helper'

class PayflowUkTest < Test::Unit::TestCase
  def setup
    @gateway = PayflowUkGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )
  end

  def test_default_currency
    assert_equal 'GBP', PayflowUkGateway.default_currency
  end
  
  def test_express_instance
    assert_instance_of PayflowExpressUkGateway, @gateway.express
  end
  
  def test_default_partner
    assert_equal 'PayPalUk', PayflowUkGateway.partner
  end
  
  def test_supported_countries
    assert_equal ['GB'], PayflowUkGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover, :solo, :switch], PayflowUkGateway.supported_cardtypes
  end
end
