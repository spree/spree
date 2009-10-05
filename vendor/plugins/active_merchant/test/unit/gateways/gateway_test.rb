require 'test_helper'

class GatewayTest < Test::Unit::TestCase
  def test_should_detect_if_a_card_is_supported
    Gateway.supported_cardtypes = [:visa, :bogus]
    assert [:visa, :bogus].all? { |supported_cardtype| Gateway.supports?(supported_cardtype) }
    
    Gateway.supported_cardtypes = []
    assert_false [:visa, :bogus].all? { |invalid_cardtype| Gateway.supports?(invalid_cardtype) }
  end
  
  def test_should_gateway_uses_ssl_strict_checking_by_default
    assert Gateway.ssl_strict
  end
  
  def test_should_be_able_to_look_for_test_mode
    Base.gateway_mode = :test
    assert Gateway.new.test?
    
    Base.gateway_mode = :production
    assert_false Gateway.new.test?
  end
  
  def test_amount_style
   assert_equal '10.34', Gateway.new.send(:amount, 1034)

   assert_raise(ArgumentError) do
     Gateway.new.send(:amount, '10.34')
   end
  end
  
  def test_invalid_type
    credit_card = stub(:type => "visa")    
    assert_equal "visa", Gateway.card_brand(credit_card)
  end
  
  def test_invalid_type  
    credit_card = stub(:type => "String", :brand => "visa")
    assert_equal "visa", Gateway.card_brand(credit_card)
  end
  
  def test_setting_application_id_outside_the_class_definition
    assert_equal SimpleTestGateway.application_id, SubclassGateway.application_id
    SimpleTestGateway.application_id = "New Application ID"
    
    assert_equal SimpleTestGateway.application_id, SubclassGateway.application_id
  end
end