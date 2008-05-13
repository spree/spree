require File.dirname(__FILE__) + '/../test_helper'

class BaseTest < Test::Unit::TestCase
  def setup
    ActiveMerchant::Billing::Base.mode = :test
  end
  
  def teardown
    ActiveMerchant::Billing::Base.mode = :test
  end
  
  def test_should_return_a_new_gateway_specified_by_symbol_name
    assert_equal BogusGateway,         Base.gateway(:bogus)
    assert_equal MonerisGateway,       Base.gateway(:moneris) 
    assert_equal AuthorizeNetGateway,  Base.gateway(:authorize_net)
    assert_equal UsaEpayGateway,       Base.gateway(:usa_epay)
    assert_equal LinkpointGateway,     Base.gateway(:linkpoint)
    assert_equal AuthorizedNetGateway, Base.gateway(:authorized_net)
  end

  def test_should_return_an_integration_by_name
    chronopay = Base.integration(:chronopay)
    
    assert_equal Integrations::Chronopay, chronopay
    assert_instance_of Integrations::Chronopay::Notification, chronopay.notification('name=cody')
  end

  def test_should_set_modes
    Base.mode = :test
    assert_equal :test, Base.mode
    assert_equal :test, Base.gateway_mode
    assert_equal :test, Base.integration_mode

    Base.mode = :production
    assert_equal :production, Base.mode
    assert_equal :production, Base.gateway_mode
    assert_equal :production, Base.integration_mode

    Base.mode             = :development
    Base.gateway_mode     = :test
    Base.integration_mode = :staging
    assert_equal :development, Base.mode
    assert_equal :test,        Base.gateway_mode
    assert_equal :staging,     Base.integration_mode
  end
  
  def test_should_identify_if_test_mode
    Base.gateway_mode = :test
    assert Base.test?
    
    Base.gateway_mode = :production
    assert_false Base.test?
  end

end
