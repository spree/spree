require File.dirname(__FILE__) + '/../test_helper'

class CountryCodeTest < Test::Unit::TestCase
  include ActiveMerchant

  def test_alpha2_country_code
    code = CountryCode.new('CA')
    assert_equal 'CA', code.value
    assert_equal 'CA', code.to_s
    assert_equal :alpha2, code.format
  end

  def test_lower_alpha2_country_code
    code = CountryCode.new('ca')
    assert_equal 'CA', code.value
    assert_equal 'CA', code.to_s
    assert_equal :alpha2, code.format
  end

  def test_alpha2_country_code
    code = CountryCode.new('CAN')
    assert_equal :alpha3, code.format
  end

  def test_numeric_code
    code = CountryCode.new('004')
    assert_equal :numeric, code.format
  end

  def test_invalid_code_format
    assert_raise(CountryCodeFormatError){ CountryCode.new('Canada') }
  end
end
