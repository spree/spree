require File.dirname(__FILE__) + '/../../test_helper'

class PayflowExpressUkTest < Test::Unit::TestCase
  def setup
    @gateway = PayflowExpressUkGateway.new(
      :login => 'LOGIN',
      :password => 'PASSWORD'
    )
  end
  
  def test_supported_countries
    assert_equal ['GB'], PayflowExpressUkGateway.supported_countries
  end
end
