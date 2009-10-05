require 'test_helper'

class RemotePayflowUkTest < Test::Unit::TestCase
  def setup
    ActiveMerchant::Billing::Base.gateway_mode = :test

    # The default partner is PayPalUk
    @gateway = PayflowUkGateway.new(fixtures(:payflow_uk))
    
    @creditcard = CreditCard.new(
      :number => '5105105105105100',
      :month => 11,
      :year => 2009,
      :first_name => 'Cody',
      :last_name => 'Fauser',
      :verification_value => '000',
      :type => 'master'
    )
    
    @solo = CreditCard.new(
      :type   => "solo",
      :number => "6334900000000005",
      :month  => Time.now.month,
      :year   => Time.now.year + 1,
      :first_name  => "Test",
      :last_name   => "Mensch",
      :issue_number => '01'
    )
    
    @switch = CreditCard.new(
       :type                => "switch",
       :number              => "5641820000000005",
       :verification_value => "000",
       :month               => 1,
       :year                => 2008,
       :first_name          => 'Fred',
       :last_name           => 'Brooks'
      )

    @options = { 
      :billing_address => {
         :name => 'Cody Fauser',
         :address1 => '1234 Shady Brook Lane',
         :city => 'Ottawa',
         :state => 'ON',
         :country => 'CA',
         :zip => '90210',
         :phone => '555-555-5555'
      },
      :email => 'cody@example.com'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(100000, @creditcard, @options)
    assert_equal "Approved", response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
  end
  
  def test_declined_purchase
    assert response = @gateway.purchase(210000, @creditcard, @options)
    assert_equal 'Failed merchant rule check', response.message
    assert_failure response
    assert response.test?
  end
  
  def test_successful_purchase_solo
     assert response = @gateway.purchase(100000, @solo, @options)
     assert_equal "Approved", response.message
     assert_success response
     assert response.test?
     assert_not_nil response.authorization
   end
  
  def test_no_card_issue_or_card_start_with_switch
    assert response = @gateway.purchase(100000, @switch, @options)
    assert_failure response
    
    assert_equal "Field format error: CARDSTART or CARDISSUE must be present", response.message
    assert_failure response
    assert response.test?
  end
  
  def test_successful_purchase_switch_with_issue_number
    @switch.issue_number = '01'
    assert response = @gateway.purchase(100000, @switch, @options)
    assert_equal "Approved", response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
  end
  
  def test_successful_purchase_switch_with_start_date
    @switch.start_month = 12
    @switch.start_year = 1999
    assert response = @gateway.purchase(100000, @switch, @options)
    assert_equal "Approved", response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
  end
  
  def test_successful_purchase_switch_with_start_date_and_issue_number
    @switch.issue_number = '05'
    @switch.start_month = 12
    @switch.start_year = 1999
    assert response = @gateway.purchase(100000, @switch, @options)
    assert_equal "Approved", response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
  end
  
  def test_successful_authorization
    assert response = @gateway.authorize(100, @creditcard, @options)
    assert_equal "Approved", response.message
    assert_success response
    assert response.test?
    assert_not_nil response.authorization
  end

  def test_authorize_and_capture
    amount = 100
    assert auth = @gateway.authorize(amount, @creditcard, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
  end
  
  def test_failed_capture
    assert response = @gateway.capture(100, '999')
    assert_failure response
    assert_equal 'Invalid tender', response.message
  end
  
  def test_authorize_and_void
    assert auth = @gateway.authorize(100, @creditcard, @options)
    assert_success auth
    assert_equal 'Approved', auth.message
    assert auth.authorization
    assert void = @gateway.void(auth.authorization)
    assert_success void
  end
  
  def test_invalid_login
    gateway = PayflowGateway.new(
      :login => '',
      :password => ''
    )
    assert response = gateway.purchase(100, @creditcard, @options)
    assert_equal 'Invalid vendor account', response.message
    assert_failure response
  end
  
  def test_duplicate_request_id
    gateway = PayflowUkGateway.new(
      :login => @login,
      :password => @password
    )
    
    request_id = Digest::SHA1.hexdigest(rand.to_s).slice(0,32)
    gateway.expects(:generate_unique_id).times(2).returns(request_id)
    
    response1 = gateway.purchase(100, @creditcard, @options)
    assert_nil response1.params['duplicate']
    response2 = gateway.purchase(100, @creditcard, @options)
    assert response2.params['duplicate']
  end
end
