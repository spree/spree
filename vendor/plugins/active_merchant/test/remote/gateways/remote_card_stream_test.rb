require 'test_helper'

class RemoteCardStreamTest < Test::Unit::TestCase
  def setup
    Base.mode = :test
    
    @gateway = CardStreamGateway.new(fixtures(:card_stream))
    
    @amex = credit_card('374245455400001',
              :month => '12',
              :year => '2009',
              :verification_value => '4887',
              :type => :american_express
            )

    @uk_maestro = credit_card('675940410531100173',
                    :month => '12',
                    :year => '2008',
                    :issue_number => '0',
                    :verification_value => '134',
                    :type => :switch
                  )
    
    @solo = credit_card('676740340572345678',
              :month => '12',
              :year => '2008',
              :issue_number => '1',
              :verification_value => '773',
              :type => :solo
            )

    @mastercard = credit_card('5301250070000191',
                    :month => '12',
                    :year => '2009',
                    :verification_value => '419',
                    :type => :master
                  )

    @declined_card = credit_card('4000300011112220',
                      :month => '9',
                      :year => '2009'
                    )

    @mastercard_options = { 
      :billing_address => { 
        :address1 => '25 The Larches',
        :city => "Narborough",
        :state => "Leicester",
        :zip => 'LE10 2RT'
      },
      :order_id => generate_unique_id,
      :description => 'Store purchase'
    }
   
    @uk_maestro_options = {
      :billing_address => { 
        :address1 => 'The Parkway',
        :address2 => "Larches Approach",
        :city => "Hull",
        :state => "North Humberside",
        :zip => 'HU7 9OP'
      },
      :order_id => generate_unique_id,
      :description => 'Store purchase'
    }
    
    @solo_options = {
      :billing_address => {
        :address1 => '5 Zigzag Road',
        :city => 'Isleworth',
        :state => 'Middlesex',
        :zip => 'TW7 8FF'
      },
      :order_id => generate_unique_id,
      :description => 'Store purchase'
    }
  end
  
  def test_successful_mastercard_purchase
    assert response = @gateway.purchase(100, @mastercard, @mastercard_options)
    assert_equal 'APPROVED', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end
  
  def test_declined_mastercard_purchase
    assert response = @gateway.purchase(10000, @mastercard, @mastercard_options)
    assert_equal 'CARD DECLINED', response.message
    assert_failure response
    assert response.test?
  end
  
  def test_expired_mastercard
    @mastercard.year = 2005
    assert response = @gateway.purchase(100, @mastercard, @mastercard_options)
    assert_equal 'CARD EXPIRED', response.message
    assert_failure response
    assert response.test?
  end

  def test_successful_maestro_purchase
    assert response = @gateway.purchase(100, @uk_maestro, @uk_maestro_options)
    assert_equal 'APPROVED', response.message
    assert_success response
  end
  
  def test_successful_solo_purchase
    assert response = @gateway.purchase(100, @solo, @solo_options)
    assert_equal 'APPROVED', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end
  
  def test_successful_amex_purchase
    assert response = @gateway.purchase(100, @amex, :order_id => generate_unique_id)
    assert_equal 'APPROVED', response.message
    assert_success response
    assert response.test?
    assert !response.authorization.blank?
  end
  
  def test_maestro_missing_start_date_and_issue_date
    @uk_maestro.issue_number = nil
    assert response = @gateway.purchase(100, @uk_maestro, @uk_maestro_options)
    assert_equal 'ISSUE NUMBER MISSING', response.message
    assert_failure response
    assert response.test?
  end
  
  def test_invalid_login
    gateway = CardStreamGateway.new(
      :login => '',
      :password => ''
    )
    assert response = gateway.purchase(100, @mastercard, @mastercard_options)
    assert_equal 'MERCHANT ID MISSING', response.message
    assert_failure response
  end
  
  def test_unsupported_merchant_currency
    assert response = @gateway.purchase(100, @mastercard, @mastercard_options.update(:currency => 'USD'))
    assert_equal "ERROR 1052", response.message
    assert_failure response
    assert response.test?
  end
end
