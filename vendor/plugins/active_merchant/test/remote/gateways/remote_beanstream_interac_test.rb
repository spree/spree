require 'test_helper'

class RemoteBeanstreamInteracTest < Test::Unit::TestCase
  
  def setup
    @gateway = BeanstreamInteracGateway.new(fixtures(:beanstream_interac))
    
    @amount = 100
    
    @options = { 
      :order_id => generate_unique_id,
      :billing_address => {
        :name => 'xiaobo zzz',
        :phone => '555-555-5555',
        :address1 => '1234 Levesque St.',
        :address2 => 'Apt B',
        :city => 'Montreal',
        :state => 'QC',
        :country => 'CA',
        :zip => 'H2C1X8'
      },
      :email => 'xiaobozzz@example.com',
      :subtotal => 800,
      :shipping => 100,
      :tax1 => 100,
      :tax2 => 100,
      :custom => 'reference one'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @options)
    assert_success response
    assert_equal "R", response.params["responseType"]
    assert_false response.redirect.blank?
  end
  
  def test_failed_confirmation
    assert response = @gateway.confirm("")
    assert_failure response
  end
  
  def test_invalid_login
    gateway = BeanstreamInteracGateway.new(
                :merchant_id => '',
                :login => '',
                :password => ''
              )
    assert response = gateway.purchase(@amount, @options)
    assert_failure response
    assert_equal 'Invalid merchant id (merchant_id = 0)', response.message
  end
end
