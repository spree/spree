require 'test_helper'

class FirstPayTest < Test::Unit::TestCase
  def setup
    @gateway = FirstPayGateway.new(:login => 'login', :password => 'password')
    
    @credit_card = credit_card
    @amount = 100
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase',
      :ip => '127.0.0.1',
      :email => 'test@test.com'
    }
  end
  
  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    
    # Replace with authorization number from the successful response
    assert_equal '57097598', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal('DECLINE', response.message)
    assert response.test?
  end
  
  def test_error_on_purchase
    @gateway.expects(:ssl_post).returns(error_response)
    
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert ! response.success?
    assert_equal('704-MISSING BASIC DATA TYPE:card, exp, zip, addr, member, amount', response.message)
    assert response.test?
  end
  
  def test_successful_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)
    @options[:credit_card] = @credit_card
    
    assert response = @gateway.credit(@amount, '123456', @options)
    assert_success response
    
    assert_equal '53147613', response.authorization
    assert response.test?    
  end
  
  def test_failed_credit
    @options[:credit_card] = @credit_card
    @gateway.expects(:ssl_post).returns(failed_credit_response)
    
    assert response = @gateway.credit(@amount, '123456', @options)
    assert_failure response
    assert_equal('PARENT TRANSACTION NOT FOUND', response.message)
    assert response.test?
  end
  
  def test_failed_unlinked_credit
    assert_raise ArgumentError do
      @gateway.credit(@amount, @credit_card)
    end
  end
  
  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    @options[:transactionid] = '123456'
    
    assert response = @gateway.void(@amount, @credit_card, @options)
    assert_success response
    
    assert_equal '53147623', response.authorization
    assert response.test?        
  end
  
  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)
    
    assert response = @gateway.void(@amount, @credit_card, @options)
    assert_failure response
    assert_equal('PARENT TRANSACTION NOT FOUND', response.message)
    assert response.test?    
  end
  
  
  private
  
  def successful_purchase_response
    "CAPTURED:056708:NA:X:Jun 02 2009:241:NLS:NLS:NLS:57097598:9999:NA:NA:NA:NA:NA:NA:NA"
  end
  
  def failed_purchase_response
    "NOT CAPTURED:DECLINE:NA:NA:Dec 11 2003:278654:NLS:NLS:NLS:53147611:200312111612:NA:NA:NA:NA:NA:NA"
  end
  
  def successful_credit_response
    "CAPTURED:945101216:199641568:NA:Dec 11 2003:278655:NLS:NLS:NLS:53147613:200312111613:NA:NA:NA:NA:NA"
  end
  
  def failed_credit_response
    "NOT CAPTURED:PARENT TRANSACTION NOT FOUND:NA:NA:Dec 11 2003:278614:NLS:NLS:NLS:53147499:200311251526:NA:NA:NA:NA:NA"
  end
  
  def successful_void_response
    "CAPTURED:000000:NA:Y:Dec 11 2003:278659:NLS:NLS:NLS:53147623:200312111628:NA:NA:NA:NA:NA"
  end
  
  def failed_void_response
    "NOT CAPTURED:PARENT TRANSACTION NOT FOUND:NA:NA:Dec 11 2003:278644:NLS:NLS:NLS:53147562:200311251526:NA:NA:NA:NA:NA"
  end
  
  def error_response
    '!ERROR! 704-MISSING BASIC DATA TYPE:card, exp, zip, addr, member, amount'
  end
end
