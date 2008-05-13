require File.dirname(__FILE__) + '/../test_helper'

class CreditCardMethodsTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::CreditCardMethods
  
  class CreditCard
    include ActiveMerchant::Billing::CreditCardMethods 
  end
  
  def maestro_card_numbers
    %w[
      5000000000000000 5099999999999999 5600000000000000
      5899999999999999 6000000000000000 6999999999999999
    ]
  end
  
  def non_maestro_card_numbers
    %w[
      4999999999999999 5100000000000000 5599999999999999 
      5900000000000000 5999999999999999 7000000000000000
    ]
  end
  
  def test_should_be_able_to_identify_valid_expiry_months
    assert_false valid_month?(-1)
    assert_false valid_month?(13)
    assert_false valid_month?(nil)
    assert_false valid_month?('')
    
    1.upto(12) { |m| assert valid_month?(m) }
  end

  def test_should_be_able_to_identify_valid_expiry_years
    assert_false valid_expiry_year?(-1)
    assert_false valid_expiry_year?(Time.now.year + 21)
    
    0.upto(20) { |n| assert valid_expiry_year?(Time.now.year + n) }
  end

  def test_should_be_able_to_identify_valid_start_years
    assert valid_start_year?(1988)
    assert valid_start_year?(2007)
    assert valid_start_year?(3000)
    
    assert_false valid_start_year?(1987)
  end
  
  def test_should_be_able_to_identify_valid_issue_numbers
    assert valid_issue_number?(1)
    assert valid_issue_number?(10)
    assert valid_issue_number?('12')
    assert valid_issue_number?(0)
    
    assert_false valid_issue_number?(-1)
    assert_false valid_issue_number?(123)
    assert_false valid_issue_number?('CAT')
  end

  def test_should_ensure_type_from_credit_card_class_is_not_frozen
    assert_false CreditCard.type?('4242424242424242').frozen?
  end
  
  def test_should_be_dankort_card_type
    assert_equal 'dankort', CreditCard.type?('5019717010103742')
  end
  
  def test_should_detect_visa_dankort_as_visa
    assert_equal 'visa', CreditCard.type?('4571100000000000')
  end
  
  def test_should_detect_electron_dk_as_visa
    assert_equal 'visa', CreditCard.type?('4175001000000000')
  end
  
  def test_should_detect_diners_club
    assert_equal 'diners_club', CreditCard.type?('36148010000000')
  end
  
  def test_should_detect_diners_club_dk
    assert_equal 'diners_club', CreditCard.type?('30401000000000')
  end
  
  def test_should_detect_maestro_dk_as_maestro
    assert_equal 'maestro', CreditCard.type?('6769271000000000')
  end
  
  def test_should_detect_maestro_cards
    assert_equal 'maestro', CreditCard.type?('5020100000000000')
    
    maestro_card_numbers.each { |number| assert_equal 'maestro', CreditCard.type?(number) }
    non_maestro_card_numbers.each { |number| assert_not_equal 'maestro', CreditCard.type?(number) }
  end
  
  def test_should_detect_mastercard
    assert_equal 'master', CreditCard.type?('6771890000000000')
    assert_equal 'master', CreditCard.type?('5413031000000000')
  end
  
  def test_should_detect_forbrugsforeningen
    assert_equal 'forbrugsforeningen', CreditCard.type?('6007221000000000')
  end
  
  def test_should_detect_laser_card
    # 16 digits
    assert_equal 'laser', CreditCard.type?('6304985028090561')
    
    # 18 digits
    assert_equal 'laser', CreditCard.type?('630498502809056151')
    
    # 19 digits
    assert_equal 'laser', CreditCard.type?('6304985028090561515')
    
    # 17 digits
    assert_not_equal 'laser', CreditCard.type?('63049850280905615')
    
    # 15 digits
    assert_not_equal 'laser', CreditCard.type?('630498502809056')
    
    # Alternate format
    assert_equal 'laser', CreditCard.type?('6706950000000000000')
  end
  
  def test_should_detect_when_an_argument_type_does_not_match_calculated_type
    assert CreditCard.matching_type?('4175001000000000', 'visa')
    assert_false CreditCard.matching_type?('4175001000000000', 'master')
  end
  
  def test_detecting_full_range_of_maestro_card_numbers
    maestro = '50000000000'
    
    assert_equal 11, maestro.length
    assert_not_equal 'maestro', CreditCard.type?(maestro)
    
    while maestro.length < 19
      maestro << '0'
      assert_equal 'maestro', CreditCard.type?(maestro)
    end
    
    assert_equal 19, maestro.length
    
    maestro << '0'
    assert_not_equal 'maestro', CreditCard.type?(maestro)
  end
  
  def test_matching_discover_card
    assert CreditCard.matching_type?('6011000000000000', 'discover')
    assert CreditCard.matching_type?('6500000000000000', 'discover')
    
    assert_false CreditCard.matching_type?('6010000000000000', 'discover')
    assert_false CreditCard.matching_type?('6600000000000000', 'discover')
  end
  
  def test_16_digit_maestro_uk
    number = '6759000000000000'
    assert_equal 16, number.length
    assert_equal 'switch', CreditCard.type?(number)
  end
  
  def test_18_digit_maestro_uk
    number = '675900000000000000'
    assert_equal 18, number.length
    assert_equal 'switch', CreditCard.type?(number)
  end
  
  def test_19_digit_maestro_uk
    number = '6759000000000000000'
    assert_equal 19, number.length
    assert_equal 'switch', CreditCard.type?(number)
  end
end
